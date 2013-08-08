////////////////////////////////////////
// Driver for WS2811-based LED strips //
////////////////////////////////////////

`include "util.v"

module ws2811
  #(
    parameter NUM_LEDS          = 4,
    parameter SYSTEM_CLOCK      = 100_000_000
    )
   (
    input                              clk,
    input                              reset,
    
    output reg [LED_ADDRESS_WIDTH-1:0] address,
    input [7:0]                        red_in,
    input [7:0]                        green_in,
    input [7:0]                        blue_in, 
    
    output                             DO
    );

   localparam LED_ADDRESS_WIDTH = `log2(NUM_LEDS);         // Number of bits to use for address input

   ////////////////////////////////////////////////////////////////////////////
   // Timing parameters for the WS2811.                                      //
   // A '0' is transmitted by driving DO high for T0H, and then low for T0L. //
   // A '1' is transmitted by driving DO high for T1H, and then low for T1L. //
   // The LEDs are reset by driving D0 low for RESET_COUNT.                  //
   ////////////////////////////////////////////////////////////////////////////
   localparam MICROSECOND_COUNT = SYSTEM_CLOCK / 1000000;  // Number of clock cycles for a microsecond
   localparam T0H_COUNT         = 0.5 * MICROSECOND_COUNT;
   localparam T0L_COUNT         = 2.0 * MICROSECOND_COUNT;
   localparam T1H_COUNT         = 1.2 * MICROSECOND_COUNT;
   localparam T1L_COUNT         = 1.3 * MICROSECOND_COUNT;
   localparam RESET_COUNT       = 75  * MICROSECOND_COUNT;
   localparam RESET_COUNT_WIDTH = `log2(RESET_COUNT);
   
   reg [RESET_COUNT_WIDTH:0]           clock_div;          // timing register
   
   localparam STATE_RESET = 3'd0;
   localparam STATE_LATCH = 3'd1;
   localparam STATE_PRE   = 3'd2;
   localparam STATE_HIGH  = 3'd3;
   localparam STATE_LOW   = 3'd4;
   localparam STATE_POST  = 3'd5;
   reg [2:0]                           state;              // FSM state

   localparam COLOR_R     = 2'd0;
   localparam COLOR_G     = 2'd1;
   localparam COLOR_B     = 2'd2;
   reg [1:0]                           color;              // Current color being transferred
                          
   reg [7:0]                           red;
   reg [7:0]                           green;
   reg [7:0]                           blue;

   reg [7:0]                           current_byte;       // Current byte to send
   reg [2:0]                           current_bit;        // Current bit index to send

   assign DO = (state == STATE_HIGH);
   
   always @ (posedge clk) begin
      if (reset) begin
         address <= 0;
         state <= STATE_RESET;
         clock_div <= RESET_COUNT;
      end
      else begin
         case (state)
           STATE_RESET: begin
              if (clock_div == 0) begin                 
                 state <= STATE_LATCH;
              end
              else begin
                 clock_div <= clock_div - 1;
              end
           end // case: STATE_RESET
           STATE_LATCH: begin
              // Latch the input
              green <= green_in;
              blue <= blue_in;
              
              // Start sending red
              color <= COLOR_R;
              current_byte <= red_in;
              current_bit <= 7;
              
              state <= STATE_PRE;
           end
           STATE_PRE: begin
              clock_div <= current_byte[7] ? T1H_COUNT : T0H_COUNT;
              state <= STATE_HIGH;
           end
           STATE_HIGH: begin
              if (clock_div == 0) begin
                 clock_div <= current_byte[7] ? T1L_COUNT : T0L_COUNT;
                 state <= STATE_LOW;
              end
              else begin
                 clock_div <= clock_div - 1;
              end
           end
           STATE_LOW: begin
              if (clock_div == 0) begin
                 state <= STATE_POST;
              end
              else begin
                 clock_div <= clock_div - 1;
              end
           end
           STATE_POST: begin
              if (current_bit != 0) begin
                 // Shift current byte to the left
                 current_byte <= {current_byte[6:0], 1'b0};
                 current_bit <= current_bit - 1;
                 state <= STATE_PRE;
              end
              else begin
                 case (color)
                    COLOR_R: begin
                       color <= COLOR_G;
                       current_byte <= green;
                       current_bit <= 7;
                    end
                   COLOR_G: begin
                      color <= COLOR_B;
                      current_byte <= blue;
                      current_bit <= 7;
                   end
                   COLOR_B: begin
                      if (address == NUM_LEDS-1)
                         address <= 0;
                      else
                        address <= address + 1;
                      state <= STATE_LATCH;
                   end
                 endcase // case (color)
              end
           end
         endcase
      end
   end
   
endmodule
