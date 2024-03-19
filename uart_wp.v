module uart_wp(
	input MAX10_CLK1_50, MAX10_CLK2_50, reset, button, button1, button2, button3,
	output [11:0] rgb,
	output hsync, vsync,
	input ADC_CLK_10,
	input [9:1] SW,
	input [1:0] KEY,
	output [3:1] LEDR, 
	output [0:0] ARDUINO_IO,
	input [0:0] GPIO,
	
	   //////////// Accelerometer ports //////////
   output		          		GSENSOR_CS_N,
   input 		     [2:1]		GSENSOR_INT,
   output		          		GSENSOR_SCLK,
   inout 		          		GSENSOR_SDI,
   inout 		          		GSENSOR_SDO
);


//Acelerometro

//===== Declaraciones Adicionales para la Actualización de los Displays
	reg [31:0] counter = 0; // Contador para controlar la actualización
	localparam COUNTER_MAX = 5000000; // Ajuste para 0.5 segundos con reloj de 50MHz
	wire update_display; // Señal para indicar cuándo actualizar los displays


//===== Declarations
   localparam SPI_CLK_FREQ  = 200;  // SPI Clock (Hz)
   localparam UPDATE_FREQ   = 1;    // Sampling frequency (Hz)

   // clks and reset
   wire reset_n;
   wire clk, spi_clk, spi_clk_out;

   // output data
   wire data_update;
   wire [15:0] data_x;

//===== Phase-locked Loop (PLL) instantiation. Code was copied from a module
//      produced by Quartus' IP Catalog tool.


// Incrementa el contador en cada ciclo de reloj y reinícialo una vez que alcance COUNTER_MAX
always @(posedge clk) begin
    if(counter >= COUNTER_MAX) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

// Genera una señal de actualización cuando el contador se reinicia
assign update_display = (counter == 0);


PLL ip_inst (
   .inclk0 ( MAX10_CLK1_50 ),
   .c0 ( clk ),                 // 25 MHz, phase   0 degrees
   .c1 ( spi_clk ),             //  2 MHz, phase   0 degrees
   .c2 ( spi_clk_out )          //  2 MHz, phase 270 degrees
   );

//===== Instantiation of the spi_control module which provides the logic to 
//      interface to the accelerometer.
spi_control #(     // parameters
      .SPI_CLK_FREQ   (SPI_CLK_FREQ),
      .UPDATE_FREQ    (UPDATE_FREQ))
   spi_ctrl (      // port connections
      .reset_n    (reset_n),
      .clk        (clk),
      .spi_clk    (spi_clk),
      .spi_clk_out(spi_clk_out),
      .data_update(data_update),
      .data_x     (data_x),
      .SPI_SDI    (GSENSOR_SDI),
      .SPI_SDO    (GSENSOR_SDO),
      .SPI_CSN    (GSENSOR_CS_N),
      .SPI_CLK    (GSENSOR_SCLK),
      .interrupt  (GSENSOR_INT)
   );

//===== Main block
//      To make the module do something visible, the 16-bit data_x is 
//      displayed on four of the HEX displays in hexadecimal format.

// Pressing KEY0 freezes the accelerometer's output
assign reset_n = KEY[0];


wire [15:0] abs_data_x;

// Asignación condicional para calcular el valor absoluto
assign abs_data_x = (data_x[15] == 1'b1) ? (~data_x + 1'b1) : data_x;

/*
wire [3:0] unidades_x = abs_data_x % 10;
wire [3:0] decenas_x = (abs_data_x / 10) % 10;
wire [3:0] centenas_x = (abs_data_x / 100) % 10;


reg [3:0] display_unidades_x;
reg [3:0] display_decenas_x;
reg [3:0] display_centenas_x;


always @(posedge clk) begin
    if (update_display) begin
        // Actualiza los registros con los valores actuales
        display_unidades_x <= unidades_x;
        display_decenas_x <= decenas_x;
        display_centenas_x <= centenas_x;
    end
end
*/
reg led_negativo_x; // Registro intermedio para manejar el LED relacionado con data_x.
reg led_negativo_y; // Registro intermedio para manejar el LED relacionado con data_y.

/*
always @(posedge clk) begin
    if (reset) begin
        // Si hay un reset, posiblemente quieras limpiar estados aquí
    end
    else begin
        // Verifica si data_x < -60 (valor absoluto para negativos)
        if (data_x[15] == 1'b1 && abs_data_x > 60) begin
            // Prepara para enviar '1'
            i_Tx_DV <= 1'b1;       // Indica que hay un byte válido para enviar
            i_Tx_Byte <= 8'b00000001; // El byte a enviar es '1'
        end else begin
            // Prepara para enviar '0'
            i_Tx_DV <= 1'b1;       // Indica que hay un byte válido para enviar
            i_Tx_Byte <= 8'b00000000; // El byte a enviar es '0'
        end
    end
end
*/

// UART

//wire [1:0] tx_out;
//wire [7:0] tx_out;
//wire [7:0] rx_out;


reg tx_Subir;       // Señal para indicar cuándo enviar datos
reg tx_Bajar;
reg tx_DV;
reg [7:0] tx_Byte; // Byte a enviar
reg [7:0] valor; // Declara 'valor' si es que va a ser utilizado.

always @(posedge clk) begin
    if (data_x[15] == 1'b0 && abs_data_x > 60) begin
        // Suponiendo que un valor positivo grande en data_x significa "subir"
        tx_Subir <= 1'b1;   // Activar "subir"
        tx_Bajar <= 1'b0;   // Asegurarse de que "bajar" esté desactivado
		  
        tx_Byte <= 8'h01;      // Asigna un valor específico para "bajar"
    end else if (data_x[15] == 1'b1 && abs_data_x > 60) begin
        // Suponiendo que un valor negativo grande en data_x significa "bajar"
        tx_Subir <= 1'b0;   // Asegurarse de que "subir" esté desactivado
        tx_Bajar <= 1'b1;   // Activar "bajar"
		  
        tx_Byte <= 8'h00;      // Asigna un valor específico para "subir"
    end else begin
        tx_Subir <= 1'b0;   // No se cumplen las condiciones para subir
        tx_Bajar <= 1'b0;   // No se cumplen las condiciones para bajar
    end
end




uart_tx WRAPPER1(
	.i_Clock(ADC_CLK_10),
	.i_Tx_DV(SW[9]),
	.i_Tx_Byte(tx_Byte),
	.o_Tx_Active(LEDR[1]),
	.o_Tx_Serial(tx_out),
	.o_Tx_Done(LEDR[2])

);


assign ARDUINO_IO[0] = tx_out;


uart_rx WRAPPER2(
	.i_Clock(ADC_CLK_10),
	.i_Rx_Serial(GPIO[0]),
	.o_Rx_DV(LEDR[3]),
	.o_Rx_Byte(rx_out)

);

wire [3:0] unidades_in1;
wire [3:0] decenas_in1;

assign unidades_in1 = (rx_out % 10);
assign decenas_in1 = ((rx_out % 100) / 10);

wire [3:0] unidades_in2;
wire [3:0] decenas_in2;

assign unidades_in2 = (SW[7:1] % 10);
assign decenas_in2 = ((SW[7:1] % 100) / 10);
/*
BCD WRAP1(
    .data_in(unidades_in1),
    .segmentos(HEX0)
);

BCD WRAP2(
    .data_in(decenas_in1),
    .segmentos(HEX1)
);

BCD WRAP3(
    .data_in(unidades_in2),
    .segmentos(HEX4)
);

BCD WRAP4(
    .data_in(decenas_in2),
    .segmentos(HEX5)
);
*/

reg tx_Subir_2;       // Señal para indicar cuándo enviar datos
reg tx_Bajar_2;

always @(posedge clk) begin
    if (rx_out == 1'b1) begin
        // Si la condición para subir es verdadera
        tx_Subir_2 <= 1'b1;   // Activar "subir"
        tx_Bajar_2 <= 1'b0;   // Asegurarse de que "bajar" esté desactivado
    end else begin
        // Si la condición para subir no es verdadera
        tx_Subir_2 <= 1'b0;   // Asegurarse de que "subir" esté desactivado
        tx_Bajar_2 <= 1'b1;   // Activar "bajar"
    end
end



	wire [9:0] x,y;
	
	wire video_on;
	wire clk_1ms;
	
	wire [11:0] rgb_paddle1, rgb_paddle2, rgb_ball;
	wire ball_on, paddle1_on, paddle2_on;
	wire [9:0] x_paddle1, x_paddle2, y_paddle1, y_paddle2;
	wire [3:0] p1_score, p2_score;
	wire [1:0] game_state;
	
	vga_sync v1	(.clk(MAX10_CLK1_50), .hsync(hsync), .vsync(vsync), .x(x), .y(y), .video_on(video_on));
	
	render r1	(.clk(MAX10_CLK1_50), .reset(reset), .x(x), .y(y), .video_on(video_on), .rgb(rgb), .clk_1ms(clk_1ms),
					.paddle1_on(paddle1_on), .paddle2_on(paddle2_on), .ball_on(ball_on), 
					.rgb_paddle1(rgb_paddle1), .rgb_paddle2(rgb_paddle2), .rgb_ball(rgb_ball),
					.game_state(game_state));
				
	clock_divider c1 (.clk(MAX10_CLK1_50), .clk_1ms(clk_1ms));
	
	ball b1 	(.clk(MAX10_CLK1_50), .clk_1ms(clk_1ms), .reset(reset), .x(x), .y(y),  .ball_on(ball_on), .rgb_ball(rgb_ball),
				.x_paddle1(x_paddle1), .x_paddle2(x_paddle2), .y_paddle1(y_paddle1), .y_paddle2(y_paddle2),
				.p1_score(p1_score), .p2_score(p2_score), .game_state(game_state));
	
	paddle p1	(.clk_1ms(clk_1ms), .reset(reset), .x(x), .y(y),
					 .button(tx_Subir), .button1(tx_Bajar),  .button2(tx_Subir_2), .button3(tx_Bajar_2),
					.paddle1_on(paddle1_on), .rgb_paddle1(rgb_paddle1), .paddle2_on(paddle2_on), .rgb_paddle2(rgb_paddle2),
					.x_paddle1(x_paddle1), .x_paddle2(x_paddle2), .y_paddle1(y_paddle1), .y_paddle2(y_paddle2) );

	game_state(.clk(MAX10_CLK1_50), .clk_1ms(clk_1ms), .reset(reset), .p1_score(p1_score), .p2_score(p2_score), .game_state(game_state));
	/*
	seven_seg (.clk(MAX10_CLK1_50), .clk_1ms(clk_1ms), .reset(reset), .p1_score(p1_score), .p2_score(p2_score), .seg1(seg1), .seg2(seg2));
	*/
	

endmodule 