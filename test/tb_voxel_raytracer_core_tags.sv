`timescale 1ns/1ps
`default_nettype none

module tb_voxel_raytracer_core_tags;
    localparam int W = 16;
    localparam int CW = 5;
    localparam int AW = 15;
    localparam int RIDW = 3;

    logic clk, rst_n;
    logic [CW-1:0] ix_in, iy_in, iz_in;
    logic sx_in, sy_in, sz_in;
    logic [W-1:0] next_x_in, next_y_in, next_z_in;
    logic [W-1:0] inc_x_in, inc_y_in, inc_z_in;
    logic [RIDW-1:0] ray_id_in;
    logic step_valid_in;
    logic load_mode, load_valid, load_ready, load_data, load_complete;
    logic [AW-1:0] load_addr;
    logic [AW:0] write_count;

    logic [CW-1:0] ix_out, iy_out, iz_out;
    logic [CW-1:0] ix_curr_out, iy_curr_out, iz_curr_out;
    logic [W-1:0] next_x_out, next_y_out, next_z_out;
    logic [2:0] face_mask_out, primary_face_id_out;
    logic [RIDW-1:0] ray_id_out;
    logic out_of_bounds_out, voxel_occupied_out, step_valid_out;

    voxel_raytracer_core #(
        .W(W), .COORD_W(CW), .MAX_VAL(31), .ADDR_BITS(AW), .RAY_ID_WIDTH(RIDW)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .ix_in(ix_in), .iy_in(iy_in), .iz_in(iz_in),
        .sx_in(sx_in), .sy_in(sy_in), .sz_in(sz_in),
        .next_x_in(next_x_in), .next_y_in(next_y_in), .next_z_in(next_z_in),
        .inc_x_in(inc_x_in), .inc_y_in(inc_y_in), .inc_z_in(inc_z_in),
        .ray_id_in(ray_id_in), .step_valid_in(step_valid_in),
        .load_mode(load_mode), .load_valid(load_valid), .load_ready(load_ready),
        .load_addr(load_addr), .load_data(load_data),
        .write_count(write_count), .load_complete(load_complete),
        .ix_out(ix_out), .iy_out(iy_out), .iz_out(iz_out),
        .ix_curr_out(ix_curr_out), .iy_curr_out(iy_curr_out), .iz_curr_out(iz_curr_out),
        .next_x_out(next_x_out), .next_y_out(next_y_out), .next_z_out(next_z_out),
        .face_mask_out(face_mask_out), .primary_face_id_out(primary_face_id_out),
        .ray_id_out(ray_id_out), .out_of_bounds_out(out_of_bounds_out),
        .voxel_occupied_out(voxel_occupied_out), .step_valid_out(step_valid_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_step(input [RIDW-1:0] rid, input valid);
        begin
            @(negedge clk);
            step_valid_in = valid;
            ray_id_in = rid;
            ix_in = rid;
            iy_in = rid + 1'b1;
            iz_in = rid + 2'd2;
            sx_in = 1'b1;
            sy_in = 1'b1;
            sz_in = 1'b1;
            next_x_in = 16'h0010 + rid;
            next_y_in = 16'h0020 + rid;
            next_z_in = 16'h0030 + rid;
            inc_x_in = 16'h0100;
            inc_y_in = 16'h0200;
            inc_z_in = 16'h0300;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        step_valid_in = 1'b0;
        load_mode = 1'b0;
        load_valid = 1'b0;
        load_addr = '0;
        load_data = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        drive_step(3'd0, 1'b1);
        drive_step(3'd1, 1'b1);
        drive_step(3'd2, 1'b0);
        drive_step(3'd3, 1'b1);
        drive_step(3'd4, 1'b1);
        drive_step(3'd5, 1'b1);
        drive_step(3'd0, 1'b0);

        repeat (20) @(posedge clk);
        $display("PASS tb_voxel_raytracer_core_tags");
        $finish;
    end

    int valid_seen;
    initial valid_seen = 0;
    always @(posedge clk) begin
        if (rst_n && step_valid_out) begin
            valid_seen++;
            if (valid_seen == 1 && ray_id_out !== 3'd0) $fatal(1, "expected ray_id 0");
            if (valid_seen == 2 && ray_id_out !== 3'd1) $fatal(1, "expected ray_id 1");
            if (valid_seen == 3 && ray_id_out !== 3'd3) $fatal(1, "expected bubble then ray_id 3");
            if (valid_seen == 4 && ray_id_out !== 3'd4) $fatal(1, "expected ray_id 4");
            if (valid_seen == 5 && ray_id_out !== 3'd5) $fatal(1, "expected ray_id 5");
        end
    end

    initial begin
        wait (rst_n);
        repeat (30) @(posedge clk);
        if (valid_seen !== 5) $fatal(1, "expected 5 valid outputs, saw %0d", valid_seen);
    end
endmodule

`default_nettype wire
