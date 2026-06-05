`timescale 1ns/1ps
`default_nettype none

module tb_step_control_multi;
    localparam int XW = 5;
    localparam int YW = 5;
    localparam int ZW = 5;
    localparam int TW = 16;
    localparam int SW = 8;
    localparam int PW = 8;
    localparam int RIDW = 3;
    localparam int NCTX = 5;

    logic clock, reset, load_mode;
    logic job_valid, job_ready;
    logic [PW-1:0] job_pixel_id;
    logic [XW-1:0] job_init_x;
    logic [YW-1:0] job_init_y;
    logic [ZW-1:0] job_init_z;
    logic job_sx, job_sy, job_sz;
    logic [TW-1:0] job_timer_x, job_timer_y, job_timer_z;
    logic [TW-1:0] job_inc_x, job_inc_y, job_inc_z;
    logic [SW-1:0] max_steps;

    logic pipeline_valid;
    logic [RIDW-1:0] pipeline_ray_id;
    logic solid_bit, out_of_bounds;
    logic [XW-1:0] pipeline_curr_x, pipeline_next_x;
    logic [YW-1:0] pipeline_curr_y, pipeline_next_y;
    logic [ZW-1:0] pipeline_curr_z, pipeline_next_z;
    logic [TW-1:0] pipeline_next_timer_x, pipeline_next_timer_y, pipeline_next_timer_z;
    logic [2:0] pipeline_face_id;

    logic issue_valid;
    logic [RIDW-1:0] issue_ray_id;
    logic [XW-1:0] issue_voxel_x;
    logic [YW-1:0] issue_voxel_y;
    logic [ZW-1:0] issue_voxel_z;
    logic issue_sx, issue_sy, issue_sz;
    logic [TW-1:0] issue_timer_x, issue_timer_y, issue_timer_z;
    logic [TW-1:0] issue_inc_x, issue_inc_y, issue_inc_z;

    logic result_valid, result_ready;
    logic [PW-1:0] result_pixel_id;
    logic result_hit, result_timeout;
    logic [XW-1:0] result_hit_x;
    logic [YW-1:0] result_hit_y;
    logic [ZW-1:0] result_hit_z;
    logic [2:0] result_face_id;
    logic [SW-1:0] result_steps;
    logic all_idle;

    step_control_multi #(
        .X_BITS(XW), .Y_BITS(YW), .Z_BITS(ZW), .TIMER_WIDTH(TW),
        .STEP_COUNT_WIDTH(SW), .PIXEL_ID_WIDTH(PW), .RAY_ID_WIDTH(RIDW),
        .NUM_CONTEXTS(NCTX), .RESULT_DEPTH(8)
    ) dut (
        .clock(clock), .reset(reset), .load_mode(load_mode),
        .job_valid(job_valid), .job_ready(job_ready), .job_pixel_id(job_pixel_id),
        .job_init_x(job_init_x), .job_init_y(job_init_y), .job_init_z(job_init_z),
        .job_sx(job_sx), .job_sy(job_sy), .job_sz(job_sz),
        .job_timer_x(job_timer_x), .job_timer_y(job_timer_y), .job_timer_z(job_timer_z),
        .job_inc_x(job_inc_x), .job_inc_y(job_inc_y), .job_inc_z(job_inc_z),
        .max_steps(max_steps),
        .pipeline_valid(pipeline_valid), .pipeline_ray_id(pipeline_ray_id),
        .solid_bit(solid_bit), .out_of_bounds(out_of_bounds),
        .pipeline_curr_x(pipeline_curr_x), .pipeline_curr_y(pipeline_curr_y), .pipeline_curr_z(pipeline_curr_z),
        .pipeline_next_x(pipeline_next_x), .pipeline_next_y(pipeline_next_y), .pipeline_next_z(pipeline_next_z),
        .pipeline_next_timer_x(pipeline_next_timer_x), .pipeline_next_timer_y(pipeline_next_timer_y),
        .pipeline_next_timer_z(pipeline_next_timer_z), .pipeline_face_id(pipeline_face_id),
        .issue_valid(issue_valid), .issue_ray_id(issue_ray_id),
        .issue_voxel_x(issue_voxel_x), .issue_voxel_y(issue_voxel_y), .issue_voxel_z(issue_voxel_z),
        .issue_sx(issue_sx), .issue_sy(issue_sy), .issue_sz(issue_sz),
        .issue_timer_x(issue_timer_x), .issue_timer_y(issue_timer_y), .issue_timer_z(issue_timer_z),
        .issue_inc_x(issue_inc_x), .issue_inc_y(issue_inc_y), .issue_inc_z(issue_inc_z),
        .result_valid(result_valid), .result_ready(result_ready),
        .result_pixel_id(result_pixel_id), .result_hit(result_hit), .result_timeout(result_timeout),
        .result_hit_x(result_hit_x), .result_hit_y(result_hit_y), .result_hit_z(result_hit_z),
        .result_face_id(result_face_id), .result_steps(result_steps), .all_idle(all_idle)
    );

    initial clock = 1'b0;
    always #5 clock = ~clock;

    logic [4:0] vpipe;
    logic [RIDW-1:0] idpipe [0:4];
    logic [XW-1:0] xpipe [0:4];
    logic [YW-1:0] ypipe [0:4];
    logic [ZW-1:0] zpipe [0:4];

    always_ff @(posedge clock) begin
        vpipe <= {vpipe[3:0], issue_valid};
        idpipe[0] <= issue_ray_id;
        xpipe[0] <= issue_voxel_x;
        ypipe[0] <= issue_voxel_y;
        zpipe[0] <= issue_voxel_z;
        for (int i = 1; i < 5; i = i + 1) begin
            idpipe[i] <= idpipe[i-1];
            xpipe[i] <= xpipe[i-1];
            ypipe[i] <= ypipe[i-1];
            zpipe[i] <= zpipe[i-1];
        end
    end

    always_comb begin
        pipeline_valid = vpipe[4];
        pipeline_ray_id = idpipe[4];
        pipeline_curr_x = xpipe[4];
        pipeline_curr_y = ypipe[4];
        pipeline_curr_z = zpipe[4];
        pipeline_next_x = xpipe[4] + 1'b1;
        pipeline_next_y = ypipe[4];
        pipeline_next_z = zpipe[4];
        pipeline_next_timer_x = 16'h0100;
        pipeline_next_timer_y = 16'h0200;
        pipeline_next_timer_z = 16'h0300;
        pipeline_face_id = idpipe[4][2:0];
        solid_bit = 1'b0;
        out_of_bounds = 1'b0;
        if (vpipe[4]) begin
            unique case (idpipe[4])
                3'd0: solid_bit = 1'b1;
                3'd1: out_of_bounds = 1'b1;
                3'd2: begin end
                3'd3: solid_bit = 1'b1;
                3'd4: out_of_bounds = 1'b1;
                default: begin end
            endcase
        end
    end

    task automatic submit_job(input int n, input [SW-1:0] steps);
        begin
            @(negedge clock);
            job_valid = 1'b1;
            job_pixel_id = 8'hA0 + n[7:0];
            job_init_x = n[XW-1:0];
            job_init_y = (n + 1);
            job_init_z = (n + 2);
            job_sx = 1'b1;
            job_sy = 1'b0;
            job_sz = 1'b1;
            job_timer_x = 16'h0010 + n;
            job_timer_y = 16'h0020 + n;
            job_timer_z = 16'h0030 + n;
            job_inc_x = 16'h0001;
            job_inc_y = 16'h0002;
            job_inc_z = 16'h0003;
            max_steps = steps;
            #1;
            if (!job_ready) $fatal(1, "job %0d was not ready before accept edge", n);
            @(posedge clock);
            job_valid = 1'b0;
        end
    endtask

    task automatic expect_result(
        input [PW-1:0] pix,
        input exp_hit,
        input exp_timeout
    );
        bit found;
        begin
            found = 1'b0;
            repeat (80) begin
                @(posedge clock);
                #1;
                if (!found && result_valid) begin
                    if (result_pixel_id !== pix) $fatal(1, "pixel mismatch got %h exp %h", result_pixel_id, pix);
                    if (result_hit !== exp_hit) $fatal(1, "hit mismatch for pixel %h", pix);
                    if (result_timeout !== exp_timeout) $fatal(1, "timeout mismatch for pixel %h", pix);
                    result_ready = 1'b1;
                    @(posedge clock);
                    result_ready = 1'b0;
                    found = 1'b1;
                end
            end
            if (!found) $fatal(1, "timed out waiting for result pixel %h", pix);
        end
    endtask

    initial begin
        reset = 1'b1;
        load_mode = 1'b0;
        job_valid = 1'b0;
        result_ready = 1'b0;
        vpipe = '0;
        max_steps = 8'd1;
        repeat (3) @(posedge clock);
        reset = 1'b0;
        repeat (2) @(posedge clock);

        if (!all_idle) $fatal(1, "all_idle should be high after reset");
        if (!job_ready) $fatal(1, "job_ready should be high after reset");

        for (int n = 0; n < 5; n = n + 1) begin
            @(negedge clock);
            job_valid = 1'b1;
            job_pixel_id = 8'hA0 + n[7:0];
            job_init_x = n[XW-1:0];
            job_init_y = (n + 1);
            job_init_z = (n + 2);
            job_sx = 1'b1;
            job_sy = 1'b0;
            job_sz = 1'b1;
            job_timer_x = 16'h0010 + n;
            job_timer_y = 16'h0020 + n;
            job_timer_z = 16'h0030 + n;
            job_inc_x = 16'h0001;
            job_inc_y = 16'h0002;
            job_inc_z = 16'h0003;
            max_steps = (n == 2) ? 8'd1 : 8'd8;
            #1;
            if (!job_ready) $fatal(1, "streamed job %0d was not ready", n);
            @(posedge clock);
        end
        @(negedge clock);
        job_valid = 1'b0;
        #1;
        if (job_ready) $fatal(1, "job_ready should be low with five occupied contexts");

        result_ready = 1'b0;
        wait (result_valid);
        #1;
        if (result_pixel_id !== 8'hA0) $fatal(1, "first queued result should be pixel A0");
        repeat (3) begin
            @(posedge clock);
            #1;
            if (!result_valid || result_pixel_id !== 8'hA0) $fatal(1, "result was not stable under backpressure");
        end

        expect_result(8'hA0, 1'b1, 1'b0);
        expect_result(8'hA1, 1'b0, 1'b0);
        expect_result(8'hA2, 1'b0, 1'b1);
        expect_result(8'hA3, 1'b1, 1'b0);
        expect_result(8'hA4, 1'b0, 1'b0);

        repeat (5) @(posedge clock);
        if (!all_idle) $fatal(1, "all_idle should return high after all results consumed");

        load_mode = 1'b1;
        #1;
        if (job_ready) $fatal(1, "job_ready should be blocked during load_mode");
        load_mode = 1'b0;

        $display("PASS tb_step_control_multi");
        $finish;
    end
endmodule

`default_nettype wire
