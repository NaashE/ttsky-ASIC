`timescale 1ns/1ps
`default_nettype none

module tb_raytracer_top_multi;
    localparam int CW = 5;
    localparam int COORD_WIDTH = 8;
    localparam int W = 16;
    localparam int AW = 15;
    localparam int SW = 10;
    localparam int PW = 8;

    logic clk, rst_n;
    logic job_valid, job_ready;
    logic [CW-1:0] job_ix0, job_iy0, job_iz0;
    logic job_sx, job_sy, job_sz;
    logic [W-1:0] job_next_x, job_next_y, job_next_z;
    logic [W-1:0] job_inc_x, job_inc_y, job_inc_z;
    logic [9:0] job_max_steps;
    logic [PW-1:0] job_pixel_id;

    logic load_mode, load_valid, load_ready, load_data, load_complete;
    logic [AW-1:0] load_addr;
    logic [AW:0] write_count;

    logic ray_done, ray_hit, ray_timeout;
    logic [COORD_WIDTH-1:0] hit_voxel_x, hit_voxel_y, hit_voxel_z;
    logic [2:0] hit_face_id;
    logic [SW-1:0] steps_taken;

    logic result_valid, result_ready;
    logic [PW-1:0] result_pixel_id;
    logic result_hit, result_timeout;
    logic [COORD_WIDTH-1:0] result_hit_voxel_x, result_hit_voxel_y, result_hit_voxel_z;
    logic [2:0] result_face_id;
    logic [SW-1:0] result_steps;
    logic tracer_idle;

    raytracer_top #(
        .COORD_WIDTH(COORD_WIDTH), .COORD_W(CW), .TIMER_WIDTH(W), .W(W),
        .MAX_VAL(31), .ADDR_BITS(AW), .X_BITS(CW), .Y_BITS(CW), .Z_BITS(CW),
        .MAX_STEPS_BITS(10), .STEP_COUNT_WIDTH(SW), .PIXEL_ID_WIDTH(PW), .RAY_ID_WIDTH(3)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .job_valid(job_valid), .job_ready(job_ready),
        .job_ix0(job_ix0), .job_iy0(job_iy0), .job_iz0(job_iz0),
        .job_sx(job_sx), .job_sy(job_sy), .job_sz(job_sz),
        .job_next_x(job_next_x), .job_next_y(job_next_y), .job_next_z(job_next_z),
        .job_inc_x(job_inc_x), .job_inc_y(job_inc_y), .job_inc_z(job_inc_z),
        .job_max_steps(job_max_steps), .job_pixel_id(job_pixel_id),
        .load_mode(load_mode), .load_valid(load_valid), .load_ready(load_ready),
        .load_addr(load_addr), .load_data(load_data), .write_count(write_count),
        .load_complete(load_complete),
        .ray_done(ray_done), .ray_hit(ray_hit), .ray_timeout(ray_timeout),
        .hit_voxel_x(hit_voxel_x), .hit_voxel_y(hit_voxel_y), .hit_voxel_z(hit_voxel_z),
        .hit_face_id(hit_face_id), .steps_taken(steps_taken),
        .result_valid(result_valid), .result_ready(result_ready),
        .result_pixel_id(result_pixel_id), .result_hit(result_hit), .result_timeout(result_timeout),
        .result_hit_voxel_x(result_hit_voxel_x), .result_hit_voxel_y(result_hit_voxel_y),
        .result_hit_voxel_z(result_hit_voxel_z), .result_face_id(result_face_id),
        .result_steps(result_steps), .tracer_idle(tracer_idle)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function automatic [AW-1:0] addr(input [CW-1:0] x, input [CW-1:0] y, input [CW-1:0] z);
        begin
            addr = {z, y, x};
        end
    endfunction

    task automatic load_voxel(input [CW-1:0] x, input [CW-1:0] y, input [CW-1:0] z, input bit solid);
        begin
            @(negedge clk);
            load_mode = 1'b1;
            load_valid = 1'b1;
            load_addr = addr(x, y, z);
            load_data = solid;
            @(negedge clk);
            load_valid = 1'b0;
            load_mode = 1'b0;
        end
    endtask

    task automatic submit_ray(input int n, input [PW-1:0] pix);
        begin
            @(negedge clk);
            job_valid = 1'b1;
            job_pixel_id = pix;
            job_ix0 = n[CW-1:0];
            job_iy0 = 5'd0;
            job_iz0 = 5'd0;
            job_sx = 1'b1;
            job_sy = 1'b1;
            job_sz = 1'b1;
            job_next_x = 16'h0001;
            job_next_y = 16'h0100;
            job_next_z = 16'h0200;
            job_inc_x = 16'h0010;
            job_inc_y = 16'h0010;
            job_inc_z = 16'h0010;
            job_max_steps = 10'd8;
            #1;
            if (!job_ready) $fatal(1, "top was not ready before ray %0d accept edge", n);
            @(posedge clk);
            @(negedge clk);
            job_valid = 1'b0;
        end
    endtask

    bit seen [0:4];
    int count;
    initial begin
        rst_n = 1'b0;
        job_valid = 1'b0;
        result_ready = 1'b0;
        load_mode = 1'b0;
        load_valid = 1'b0;
        load_addr = '0;
        load_data = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        load_voxel(5'd0, 5'd0, 5'd0, 1'b1);
        load_voxel(5'd3, 5'd0, 5'd0, 1'b1);
        repeat (3) @(posedge clk);

        submit_ray(0, 8'h10);
        submit_ray(1, 8'h11);
        submit_ray(2, 8'h12);
        submit_ray(3, 8'h13);
        submit_ray(4, 8'h14);

        count = 0;
        result_ready = 1'b1;
        repeat (200) begin
            @(posedge clk);
            #1;
            if (result_valid) begin
                if (result_pixel_id < 8'h10 || result_pixel_id > 8'h14)
                    $fatal(1, "unexpected pixel id %h", result_pixel_id);
                seen[result_pixel_id - 8'h10] = 1'b1;
                count++;
                if (result_pixel_id == 8'h10 && !result_hit) $fatal(1, "ray 0 should hit starting voxel");
                if (result_pixel_id == 8'h13 && !result_hit) $fatal(1, "ray 3 should hit loaded voxel");
                if (count == 5) begin
                    for (int i = 0; i < 5; i = i + 1)
                        if (!seen[i]) $fatal(1, "missing result index %0d", i);
                    wait (tracer_idle);
                    $display("PASS tb_raytracer_top_multi");
                    $finish;
                end
            end
        end
        $fatal(1, "timed out waiting for top results, saw %0d", count);
    end
endmodule

`default_nettype wire
