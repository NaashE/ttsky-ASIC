// =============================================================================
// Streaming QSPI voxel ray stepper.
//
// This implementation intentionally keeps all large scene storage off chip. The
// host streams one voxel occupancy bit at a time, the ASIC advances one DDA step,
// and the host reads back the next coordinate or final result.
// =============================================================================
`default_nettype none

module qspi_stream_raytracer (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    localparam [7:0] CMD_RESET         = 8'h00;
    localparam [7:0] CMD_WRITE_CONTEXT = 8'h10;
    localparam [7:0] CMD_WRITE_VOXEL   = 8'h20;
    localparam [7:0] CMD_STEP          = 8'h30;
    localparam [7:0] CMD_READ_STATUS   = 8'h40;
    localparam [7:0] CMD_READ_COORDS   = 8'h41;
    localparam [7:0] CMD_READ_RESULT   = 8'h42;

    localparam [5:0] SCENE_MAX = 6'd31;
    localparam [4:0] CONTEXT_BYTES = 5'd18;

    wire qspi_sck_in  = ui_in[0];
    wire qspi_cs_n_in = ui_in[1];

    reg sck_meta;
    reg sck_sync;
    reg sck_prev;
    reg cs_meta;
    reg cs_sync;
    reg cs_prev;
    reg [3:0] dq_meta;
    reg [3:0] dq_sync;

    wire cs_active = ~cs_sync;
    wire sck_rise  = cs_active &  sck_sync & ~sck_prev;
    wire sck_fall  = cs_active & ~sck_sync &  sck_prev;
    wire cs_start  = ~cs_sync & cs_prev;
    wire cs_end    =  cs_sync & ~cs_prev;

    reg [7:0] cmd_shift;
    reg       cmd_half;
    reg [7:0] active_cmd;
    reg       payload_half;
    reg [3:0] payload_hi;
    reg [4:0] payload_index;
    reg       receiving_payload;

    reg       tx_active;
    reg       tx_phase;
    reg [3:0] tx_nibble;
    reg [3:0] tx_index;
    reg [1:0] tx_packet;
    reg [3:0] tx_len;

    reg [5:0] voxel_x;
    reg [5:0] voxel_y;
    reg [5:0] voxel_z;
    reg       step_x_neg;
    reg       step_y_neg;
    reg       step_z_neg;
    reg [15:0] timer_x;
    reg [15:0] timer_y;
    reg [15:0] timer_z;
    reg [15:0] inc_x;
    reg [15:0] inc_y;
    reg [15:0] inc_z;
    reg [7:0] max_steps;
    reg [7:0] pixel_id;
    reg [7:0] step_count;
    reg [2:0] face_id;

    reg active;
    reg needs_voxel;
    reg voxel_valid;
    reg voxel_occupied;
    reg result_valid;
    reg result_hit;
    reg result_timeout;

    wire [7:0] status_byte = {
        1'b0,
        tx_active,
        active & ~result_valid,
        result_timeout,
        result_hit,
        result_valid,
        needs_voxel,
        active
    };

    wire out_of_bounds =
        (voxel_x > SCENE_MAX) |
        (voxel_y > SCENE_MAX) |
        (voxel_z > SCENE_MAX);

    function [7:0] packet_byte;
        input [1:0] packet;
        input [3:0] index;
        begin
            packet_byte = 8'h00;
            case (packet)
                2'd0: begin
                    case (index)
                        4'd0: packet_byte = status_byte;
                        4'd1: packet_byte = step_count;
                        default: packet_byte = 8'h00;
                    endcase
                end
                2'd1: begin
                    case (index)
                        4'd0: packet_byte = {2'b00, voxel_x};
                        4'd1: packet_byte = {2'b00, voxel_y};
                        4'd2: packet_byte = {2'b00, voxel_z};
                        4'd3: packet_byte = step_count;
                        4'd4: packet_byte = {5'b00000, face_id};
                        default: packet_byte = 8'h00;
                    endcase
                end
                default: begin
                    case (index)
                        4'd0: packet_byte = status_byte;
                        4'd1: packet_byte = {2'b00, voxel_x};
                        4'd2: packet_byte = {2'b00, voxel_y};
                        4'd3: packet_byte = {2'b00, voxel_z};
                        4'd4: packet_byte = step_count;
                        4'd5: packet_byte = {5'b00000, face_id};
                        4'd6: packet_byte = pixel_id;
                        default: packet_byte = 8'h00;
                    endcase
                end
            endcase
        end
    endfunction

    function [3:0] packet_nibble;
        input [1:0] packet;
        input [3:0] index;
        input       high_half;
        reg [7:0] value;
        begin
            value = packet_byte(packet, index);
            packet_nibble = high_half ? value[7:4] : value[3:0];
        end
    endfunction

    task clear_engine;
        begin
            voxel_x        <= 6'd0;
            voxel_y        <= 6'd0;
            voxel_z        <= 6'd0;
            step_x_neg     <= 1'b0;
            step_y_neg     <= 1'b0;
            step_z_neg     <= 1'b0;
            timer_x        <= 16'd0;
            timer_y        <= 16'd0;
            timer_z        <= 16'd0;
            inc_x          <= 16'd0;
            inc_y          <= 16'd0;
            inc_z          <= 16'd0;
            max_steps      <= 8'd0;
            pixel_id       <= 8'd0;
            step_count     <= 8'd0;
            face_id        <= 3'd0;
            active         <= 1'b0;
            needs_voxel    <= 1'b0;
            voxel_valid    <= 1'b0;
            voxel_occupied <= 1'b0;
            result_valid   <= 1'b0;
            result_hit     <= 1'b0;
            result_timeout <= 1'b0;
        end
    endtask

    task start_tx;
        input [1:0] packet;
        input [3:0] length;
        begin
            tx_active <= 1'b1;
            tx_phase  <= 1'b0;
            tx_index  <= 4'd0;
            tx_packet <= packet;
            tx_len    <= length;
            tx_nibble <= packet_nibble(packet, 4'd0, 1'b1);
        end
    endtask

    task accept_context_byte;
        input [4:0] index;
        input [7:0] value;
        begin
            case (index)
                5'd0:  voxel_x    <= value[5:0];
                5'd1:  voxel_y    <= value[5:0];
                5'd2:  voxel_z    <= value[5:0];
                5'd3:  begin
                    step_x_neg <= value[0];
                    step_y_neg <= value[1];
                    step_z_neg <= value[2];
                end
                5'd4:  timer_x[15:8] <= value;
                5'd5:  timer_x[7:0]  <= value;
                5'd6:  timer_y[15:8] <= value;
                5'd7:  timer_y[7:0]  <= value;
                5'd8:  timer_z[15:8] <= value;
                5'd9:  timer_z[7:0]  <= value;
                5'd10: inc_x[15:8]   <= value;
                5'd11: inc_x[7:0]    <= value;
                5'd12: inc_y[15:8]   <= value;
                5'd13: inc_y[7:0]    <= value;
                5'd14: inc_z[15:8]   <= value;
                5'd15: inc_z[7:0]    <= value;
                5'd16: max_steps     <= value;
                5'd17: begin
                    pixel_id       <= value;
                    step_count     <= 8'd0;
                    face_id        <= 3'd0;
                    active         <= 1'b1;
                    needs_voxel    <= 1'b1;
                    voxel_valid    <= 1'b0;
                    result_valid   <= 1'b0;
                    result_hit     <= 1'b0;
                    result_timeout <= 1'b0;
                end
                default: begin end
            endcase
        end
    endtask

    task run_step;
        reg choose_x;
        reg choose_y;
        reg [5:0] next_x;
        reg [5:0] next_y;
        reg [5:0] next_z;
        begin
            if (active && voxel_valid && !result_valid) begin
                if (voxel_occupied) begin
                    result_valid <= 1'b1;
                    result_hit   <= 1'b1;
                    needs_voxel  <= 1'b0;
                end else if (out_of_bounds || (step_count >= max_steps)) begin
                    result_valid   <= 1'b1;
                    result_timeout <= 1'b1;
                    needs_voxel    <= 1'b0;
                end else begin
                    choose_x = (timer_x <= timer_y) && (timer_x <= timer_z);
                    choose_y = (timer_y <  timer_x) && (timer_y <= timer_z);
                    next_x = voxel_x;
                    next_y = voxel_y;
                    next_z = voxel_z;

                    if (choose_x) begin
                        next_x = step_x_neg ? (voxel_x - 6'd1) : (voxel_x + 6'd1);
                        timer_x <= timer_x + inc_x;
                        face_id <= step_x_neg ? 3'd1 : 3'd2;
                    end else if (choose_y) begin
                        next_y = step_y_neg ? (voxel_y - 6'd1) : (voxel_y + 6'd1);
                        timer_y <= timer_y + inc_y;
                        face_id <= step_y_neg ? 3'd3 : 3'd4;
                    end else begin
                        next_z = step_z_neg ? (voxel_z - 6'd1) : (voxel_z + 6'd1);
                        timer_z <= timer_z + inc_z;
                        face_id <= step_z_neg ? 3'd5 : 3'd6;
                    end

                    voxel_x     <= next_x;
                    voxel_y     <= next_y;
                    voxel_z     <= next_z;
                    step_count  <= step_count + 8'd1;
                    voxel_valid <= 1'b0;
                    needs_voxel <= 1'b1;

                    if ((next_x > SCENE_MAX) || (next_y > SCENE_MAX) || (next_z > SCENE_MAX) ||
                        ((step_count + 8'd1) >= max_steps)) begin
                        result_valid   <= 1'b1;
                        result_timeout <= 1'b1;
                        needs_voxel    <= 1'b0;
                    end
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            sck_meta          <= 1'b0;
            sck_sync          <= 1'b0;
            sck_prev          <= 1'b0;
            cs_meta           <= 1'b1;
            cs_sync           <= 1'b1;
            cs_prev           <= 1'b1;
            dq_meta           <= 4'd0;
            dq_sync           <= 4'd0;
            cmd_shift         <= 8'd0;
            cmd_half          <= 1'b0;
            active_cmd        <= 8'd0;
            payload_half      <= 1'b0;
            payload_hi        <= 4'd0;
            payload_index     <= 5'd0;
            receiving_payload <= 1'b0;
            tx_active         <= 1'b0;
            tx_phase          <= 1'b0;
            tx_nibble         <= 4'd0;
            tx_index          <= 4'd0;
            tx_packet         <= 2'd0;
            tx_len            <= 4'd0;
            clear_engine();
        end else begin
            sck_meta <= qspi_sck_in;
            sck_sync <= sck_meta;
            sck_prev <= sck_sync;
            cs_meta  <= qspi_cs_n_in;
            cs_sync  <= cs_meta;
            cs_prev  <= cs_sync;
            dq_meta  <= uio_in[3:0];
            dq_sync  <= dq_meta;

            if (cs_start || cs_end) begin
                cmd_half          <= 1'b0;
                payload_half      <= 1'b0;
                receiving_payload <= 1'b0;
                tx_active         <= 1'b0;
                tx_nibble         <= 4'd0;
            end

            if (sck_rise && !tx_active) begin
                if (!cmd_half) begin
                    cmd_shift <= {dq_sync, 4'h0};
                    cmd_half  <= 1'b1;
                end else if (!receiving_payload) begin
                    active_cmd <= {cmd_shift[7:4], dq_sync};
                    cmd_half   <= 1'b0;
                    case ({cmd_shift[7:4], dq_sync})
                        CMD_RESET: begin
                            clear_engine();
                        end
                        CMD_WRITE_CONTEXT: begin
                            receiving_payload <= 1'b1;
                            payload_index     <= 5'd0;
                            payload_half      <= 1'b0;
                        end
                        CMD_WRITE_VOXEL: begin
                            receiving_payload <= 1'b1;
                            payload_index     <= 5'd0;
                            payload_half      <= 1'b0;
                        end
                        CMD_STEP: begin
                            run_step();
                        end
                        CMD_READ_STATUS: begin
                            start_tx(2'd0, 4'd2);
                        end
                        CMD_READ_COORDS: begin
                            start_tx(2'd1, 4'd5);
                        end
                        CMD_READ_RESULT: begin
                            start_tx(2'd2, 4'd7);
                        end
                        default: begin end
                    endcase
                end else if (!payload_half) begin
                    payload_hi   <= dq_sync;
                    payload_half <= 1'b1;
                end else begin
                    payload_half <= 1'b0;
                    if (active_cmd == CMD_WRITE_CONTEXT) begin
                        accept_context_byte(payload_index, {payload_hi, dq_sync});
                        payload_index <= payload_index + 5'd1;
                        if (payload_index == (CONTEXT_BYTES - 5'd1)) begin
                            receiving_payload <= 1'b0;
                        end
                    end else if (active_cmd == CMD_WRITE_VOXEL) begin
                        voxel_occupied    <= dq_sync[0];
                        voxel_valid       <= 1'b1;
                        needs_voxel       <= 1'b0;
                        receiving_payload <= 1'b0;
                    end
                end
            end

            if (sck_fall && tx_active) begin
                if (!tx_phase) begin
                    tx_nibble <= packet_nibble(tx_packet, tx_index, 1'b0);
                    tx_phase  <= 1'b1;
                end else begin
                    tx_phase <= 1'b0;
                    if ((tx_index + 4'd1) >= tx_len) begin
                        tx_active <= 1'b0;
                        tx_nibble <= 4'd0;
                    end else begin
                        tx_index  <= tx_index + 4'd1;
                        tx_nibble <= packet_nibble(tx_packet, tx_index + 4'd1, 1'b1);
                    end
                end
            end
        end
    end

    assign uio_out = {4'h0, tx_nibble};
    assign uio_oe  = {4'h0, {4{tx_active}}};
    assign uo_out  = status_byte;

endmodule

`default_nettype wire
