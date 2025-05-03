module sha256 #(parameter MESSAGE_LEN = 640)(
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input [9:0] message_in,
    output logic [9:0] hash_out,
    output logic valid_out
);

logic [31:0] k[64];
assign {k[0], k[1], k[2], k[3], k[4], k[5], k[6], k[7], k[8], k[9], k[10], 
    k[11], k[12], k[13], k[14], k[15], k[16], k[17], k[18], k[19], k[20],
    k[21], k[22], k[23], k[24], k[25], k[26], k[27], k[28], k[29], k[30],
    k[31], k[32], k[33], k[34], k[35], k[36], k[37], k[38], k[39], k[40],
    k[41], k[42], k[43], k[44], k[45], k[46], k[47], k[48], k[49], k[50],
    k[51], k[52], k[53], k[54], k[55], k[56], k[57], k[58], k[59], k[60],
    k[61], k[62], k[63]} = {
   32'h428a2f98,32'h71374491,32'hb5c0fbcf,32'he9b5dba5,32'h3956c25b,32'h59f111f1,32'h923f82a4,32'hab1c5ed5,
   32'hd807aa98,32'h12835b01,32'h243185be,32'h550c7dc3,32'h72be5d74,32'h80deb1fe,32'h9bdc06a7,32'hc19bf174,
   32'he49b69c1,32'hefbe4786,32'h0fc19dc6,32'h240ca1cc,32'h2de92c6f,32'h4a7484aa,32'h5cb0a9dc,32'h76f988da,
   32'h983e5152,32'ha831c66d,32'hb00327c8,32'hbf597fc7,32'hc6e00bf3,32'hd5a79147,32'h06ca6351,32'h14292967,
   32'h27b70a85,32'h2e1b2138,32'h4d2c6dfc,32'h53380d13,32'h650a7354,32'h766a0abb,32'h81c2c92e,32'h92722c85,
   32'ha2bfe8a1,32'ha81a664b,32'hc24b8b70,32'hc76c51a3,32'hd192e819,32'hd6990624,32'hf40e3585,32'h106aa070,
   32'h19a4c116,32'h1e376c08,32'h2748774c,32'h34b0bcb5,32'h391c0cb3,32'h4ed8aa4a,32'h5b9cca4f,32'h682e6ff3,
   32'h748f82ee,32'h78a5636f,32'h84c87814,32'h8cc70208,32'h90befffa,32'ha4506ceb,32'hbef9a3f7,32'hc67178f2
};

logic [MESSAGE_LEN-1:0] input_message; // buffer for the message
logic [$clog2(MESSAGE_LEN/10):0] loading_counter; // counter for loading the message

logic [511:0] input_blocks [2];
logic [31:0] W [64];
logic block_flag;

// always_comb begin : Words
//     for (int i = 0; i < 64; i++) begin
//         if (i < 16) begin
//             W[i] = input_blocks[block_flag][(15-i)*32 +:32];
//         end else begin
//             W[i] = W[i-16] + (rightrotate(W[i-15],7) ^ rightrotate(W[i-15],18) ^ (W[i-15] >> 3)) + W[i-7] + (rightrotate(W[i-2],17) ^ rightrotate(W[i-2],19) ^ (W[i-2] >> 10));
//         end
//     end
// end

// digest buffers
logic [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
logic [31:0] A, B, C, D, E, F, G, H;
// pipeline registers
// logic [31:0] A_t, B_t, C_t, D_t, E_t, F_t, G_t, H_t;
logic [31:0] S_0, maj, S_1, ch;
logic [31:0] temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8;

logic [7:0] process1_counter;
logic [7:0] process2_counter;

logic [5:0] out_counter;
logic [259:0] out_buffer;
logic [1:0] padding_flag;

logic [6:0] waiting_counter;

// states
localparam STATE_IDLE = 3'd0,
           STATE_LOADING = 3'd1,
           STATE_PADDING = 3'd2,
           STATE_WAITING_W_1 = 3'd7,
           STATE_PROCESSING1 = 3'd3,
           STATE_WAITING_W_2= 3'd6,
           STATE_PROCESSING2 = 3'd4,
           STATE_DONE = 3'd5;
logic [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        // reset state
        state <= STATE_IDLE;
        input_message <= 640'd0;
        loading_counter <= 7'd0;
        valid_out <= 1'b0;
        hash_out <= 10'd0;
        input_blocks[0] <= 512'd0;
        input_blocks[1] <= 512'd0;
        block_flag <= 1'b0;
        // {W[0], W[1], W[2], W[3], W[4], W[5], W[6], W[7]} <= 512'd0;
        {H0, H1, H2, H3, H4, H5, H6, H7} <= 256'd0;
        {A, B, C, D, E, F, G, H} <= 256'd0;
        {S_0, maj, S_1, ch} <= 128'd0;
        {temp1, temp2, temp3, temp4} <= 128'd0;
        {temp5, temp6, temp7, temp8} <= 128'd0;
        process1_counter <= 8'd0;
        process2_counter <= 8'd0;
        out_counter <= 6'd0;
        padding_flag <= 2'b0;
        waiting_counter <= 7'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    H0 <= 32'h6a09e667;
                    H1 <= 32'hbb67ae85;
                    H2 <= 32'h3c6ef372;
                    H3 <= 32'ha54ff53a;
                    H4 <= 32'h510e527f;
                    H5 <= 32'h9b05688c;
                    H6 <= 32'h1f83d9ab;
                    H7 <= 32'h5be0cd19;
                    state <= STATE_LOADING;
                end
            end

            STATE_LOADING: begin
                if (valid_in && loading_counter < 64) begin
                    input_message <= {input_message[MESSAGE_LEN-11:0], message_in};
                    loading_counter <= loading_counter + 1;
                end
                if (loading_counter == 64) begin
                    state <= STATE_PADDING;
                end
            end

            STATE_PADDING: begin
                input_blocks[0] <= {input_message[MESSAGE_LEN-1:MESSAGE_LEN-512]}; 
                input_blocks[1] <= {input_message[MESSAGE_LEN-513:0], 1'b1, 319'b0, 64'd640}; 
                A <= H0;
                B <= H1;
                C <= H2;
                D <= H3;
                E <= H4;
                F <= H5;
                G <= H6;
                H <= H7;
                state <= STATE_WAITING_W_1;
            end

            STATE_WAITING_W_1: begin
                waiting_counter <= waiting_counter + 1;
                if (waiting_counter < 16) begin
                    W[waiting_counter[5:0]] <= input_blocks[0][(15-waiting_counter[5:0])*32 +:32];
                end 
                else if (waiting_counter < 64) begin
                    W[waiting_counter[5:0]] <= W[waiting_counter[5:0]-16] + (rightrotate(W[waiting_counter[5:0]-15],7) ^ rightrotate(W[waiting_counter[5:0]-15],18) ^ (W[waiting_counter[5:0]-15] >> 3)) + 
                        W[waiting_counter[5:0]-7] + (rightrotate(W[waiting_counter[5:0]-2],17) ^ rightrotate(W[waiting_counter[5:0]-2],19) ^ (W[waiting_counter[5:0]-2] >> 10));
                end
                else begin
                    waiting_counter <= 7'd0;
                    state <= STATE_PROCESSING1;
                end
            end

            STATE_PROCESSING1: begin
                if (process1_counter < 64) begin
                    if (padding_flag == 2'b00) begin
                        S_0 <= (rightrotate(A,2) ^ rightrotate(A,13) ^ rightrotate(A,22));
                        maj <= (A & B) ^ (A & C) ^ (B & C);
                        S_1 <= (rightrotate(E,6) ^ rightrotate(E,11) ^ rightrotate(E,25));
                        ch <= (E & F) ^ (~E & G);
                        padding_flag <= 2'b01;
                    end
                    else if (padding_flag == 2'b01) begin
                        temp1 <= S_1 + ch;
                        temp2 <= S_0 + maj;
                        temp3 <= k[process1_counter[5:0]] + W[process1_counter[5:0]];
                        temp4 <= D + H;
                        temp5 <= S_1 + ch;
                        // temp4 <= k[process1_counter[5:0]] + W[process1_counter[5:0]];
                        padding_flag <= 2'b10;
                    end
                    else if (padding_flag == 2'b10) begin
                        temp6 <= temp1 + temp2;
                        temp7 <= temp3 + H;
                        temp8 <= temp4 + temp5;
                        padding_flag <= 2'b11;
                    end
                    else begin
                        // A <= H + S_1 + ch + k[process1_counter[5:0]] + W[process1_counter[5:0]] + S_0 + maj;
                        A <= temp6 + temp7;
                        B <= A;
                        C <= B;
                        D <= C;
                        // E <= D + H + S_1 + ch + k[process1_counter[5:0]] + W[process1_counter[5:0]];
                        E <= temp3 + temp8;
                        F <= E;
                        G <= F;
                        H <= G;
                        padding_flag <= 2'b00;
                        process1_counter <= process1_counter + 1;
                    end
                end
                else if (process1_counter >= 64) begin
                    H0 <= H0 + A;
                    H1 <= H1 + B;
                    H2 <= H2 + C;
                    H3 <= H3 + D;
                    H4 <= H4 + E;
                    H5 <= H5 + F;
                    H6 <= H6 + G;
                    H7 <= H7 + H;
                    A <= H0 + A;
                    B <= H1 + B;
                    C <= H2 + C;
                    D <= H3 + D;
                    E <= H4 + E;
                    F <= H5 + F;
                    G <= H6 + G;
                    H <= H7 + H;
                    state <= STATE_WAITING_W_2;
                    block_flag <= 1'b1;
                end
            end

            STATE_WAITING_W_2: begin
                waiting_counter <= waiting_counter + 1;
                if (waiting_counter < 16) begin
                    W[waiting_counter[5:0]] <= input_blocks[1][(15-waiting_counter[5:0])*32 +:32];
                end 
                else if (waiting_counter < 64) begin
                    W[waiting_counter[5:0]] <= W[waiting_counter[5:0]-16] + (rightrotate(W[waiting_counter[5:0]-15],7) ^ rightrotate(W[waiting_counter[5:0]-15],18) ^ (W[waiting_counter[5:0]-15] >> 3)) + 
                        W[waiting_counter[5:0]-7] + (rightrotate(W[waiting_counter[5:0]-2],17) ^ rightrotate(W[waiting_counter[5:0]-2],19) ^ (W[waiting_counter[5:0]-2] >> 10));
                end
                else begin
                    waiting_counter <= 7'd0;
                    state <= STATE_PROCESSING2;
                end
            end

            STATE_PROCESSING2: begin
                if (process2_counter < 64) begin
                    if (padding_flag == 2'b00) begin
                        S_0 <= (rightrotate(A,2) ^ rightrotate(A,13) ^ rightrotate(A,22));
                        maj <= (A & B) ^ (A & C) ^ (B & C);
                        S_1 <= (rightrotate(E,6) ^ rightrotate(E,11) ^ rightrotate(E,25));
                        ch <= (E & F) ^ (~E & G);
                        padding_flag <= 2'b01;
                    end
                    else if (padding_flag == 2'b01) begin
                        temp1 <= S_1 + ch;
                        temp2 <= S_0 + maj;
                        temp3 <= k[process2_counter[5:0]] + W[process2_counter[5:0]];
                        temp4 <= D + H;
                        temp5 <= S_1 + ch;
                        // temp4 <= k[process1_counter[5:0]] + W[process1_counter[5:0]];
                        padding_flag <= 2'b10;
                    end
                    else if (padding_flag == 2'b10) begin
                        temp6 <= temp1 + temp2;
                        temp7 <= temp3 + H;
                        temp8 <= temp4 + temp5;
                        padding_flag <= 2'b11;
                    end
                    else begin
                        // A <= H + S_1 + ch + k[process2_counter[5:0]] + W[process2_counter[5:0]] + S_0 + maj;
                        A <= temp6 + temp7;
                        B <= A;
                        C <= B;
                        D <= C;
                        // E <= D + H + S_1 + ch + k[process2_counter[5:0]] + W[process2_counter[5:0]];
                        E <= temp3 + temp8;
                        F <= E;
                        G <= F;
                        H <= G;
                        padding_flag <= 2'b00;
                        process2_counter <= process2_counter + 1;
                    end
                end
                else if (process2_counter >= 64) begin
                    H0 <= H0 + A;
                    H1 <= H1 + B;
                    H2 <= H2 + C;
                    H3 <= H3 + D;
                    H4 <= H4 + E;
                    H5 <= H5 + F;
                    H6 <= H6 + G;
                    H7 <= H7 + H;
                    state <= STATE_DONE;
                end
            end

            STATE_DONE: begin
                if (out_counter == 0) begin
                    out_buffer <= {H0, H1, H2, H3, H4, H5, H6, H7, 4'b0};
                    out_counter <= out_counter + 1;
                end
                else if (out_counter > 0 && out_counter < 27) begin
                    hash_out <= out_buffer[259:250];
                    out_buffer <= out_buffer << 10;
                    out_counter <= out_counter + 1;
                    valid_out <= 1'b1;
                end
                else if (out_counter >= 28) begin
                    valid_out <= 1'b0;
                    state <= STATE_IDLE;
                end
            end

        endcase
    end
end

function logic [31:0] rightrotate(input [31:0] a, input [7:0] b);
    rightrotate = (a>>b)|(a<<(32-b));
endfunction





endmodule