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
    
    output reg                         DO
    );

   localparam LED_ADDRESS_WIDTH = `log2(NUM_LEDS);         // Number of bits to use for address input

   
   /////////////////////////////////////////////////////////////
   // Timing parameters for the WS2811                        //
   // The LEDs are reset by driving D0 low for at least 50us. //
   // Data is transmitted using a 400kHz signal.              //
   // A '1' is 50% duty cycle, a '0' is 20% duty cycle.       //
   /////////////////////////////////////////////////////////////
     
   localparam US_COUNT            = SYSTEM_CLOCK / 1000000;  // Number of clock cycles in a microsecond
   localparam CYCLE_COUNT         = 2.5 * US_COUNT;
   localparam H0_CYCLE_COUNT      = 0.2 * CYCLE_COUNT;
   localparam H1_CYCLE_COUNT      = 0.5 * CYCLE_COUNT;
   localparam CLOCK_DIV_WIDTH     = `log2(CYCLE_COUNT);
   localparam RESET_COUNT         = 75 * US_COUNT;
   localparam RESET_COUNTER_WIDTH = `log2(RESET_COUNT);

   reg [CLOCK_DIV_WIDTH-1:0]             clock_div;           // Clock divider for a cycle
   reg [RESET_COUNTER_WIDTH-1:0]         reset_counter;       // Counter for a reset cycle
   
   localparam STATE_RESET    = 3'd0;
   localparam STATE_LATCH    = 3'd1;
   localparam STATE_PRE      = 3'd2;
   localparam STATE_TRANSMIT = 3'd3;
   localparam STATE_POST     = 3'd4;
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
   
   always @ (posedge clk) begin
      if (reset) begin
         address <= 0;
         state <= STATE_RESET;
         DO <= 0;
         reset_counter <= 0;
      end
      else begin
         case (state)
           STATE_RESET: begin
              DO <= 0;
              if (reset_counter == RESET_COUNT-1) begin
                 reset_counter <= 0;
                 state <= STATE_LATCH;
              end
              else begin
                 reset_counter <= reset_counter + 1;
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
              clock_div <= 0;
              DO <= 1;
              state <= STATE_TRANSMIT;
           end
           STATE_TRANSMIT: begin
              if (current_byte[7] == 0 && clock_div == H0_CYCLE_COUNT) begin
                 DO <= 0;
              end
              else if (current_byte[7] == 1 && clock_div == H1_CYCLE_COUNT) begin
                 DO <= 0;
              end
              if (clock_div == CYCLE_COUNT-1) begin
                 state <= STATE_POST;
              end
              else begin
                 clock_div <= clock_div + 1;
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
                      if (address == NUM_LEDS-1) begin
                         address <= 0;
                         state <= STATE_RESET;
                      end
                      else begin
                        address <= address + 1;
                         state <= STATE_LATCH;
                      end
                   end
                 endcase // case (color)
              end
           end
         endcase
      end
   end
   
endmodule
