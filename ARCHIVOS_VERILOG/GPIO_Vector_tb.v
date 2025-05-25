`timescale 1ns / 1ps

module gpio_vector_tb;
    // Parámetros del testbench
    parameter CLK_PERIOD = 10; // 10ns = 100MHz

    // Señales para conectar con el DUT (Device Under Test)
    wire [15:0] PIN_DATA;       // Vector de datos bidireccionales (inout)
    reg clk;                    // Señal de reloj
    integer j;
    reg reset;                  // Señal de reset
    reg Enable;                 // Habilitador del módulo (activo en bajo)
    reg [15:0] Function;        // Configuración: 0=entrada, 1=salida para cada pin
    reg [15:0] Data_out;        // Datos de salida
    reg [15:0] Pin_Change_Mask; // Habilitación de interrupción por cambio
    reg [1:0] Int_Mask;         // Tipo de interrupción
    wire [15:0] Data_in;        // Datos leídos desde PIN_DATA
    wire [15:0] Pin_out;        // Datos escritos al exterior
    wire IRQ_PIN_CHANGE;        // Señal global de interrupción por cambio
    wire [1:0] IRQ_INT;         // Señales de interrupción para pines 14 y 15

    // Registros para simular entradas externas al PIN_DATA
    reg [15:0] external_pin_data;  // Datos externos aplicados a PIN_DATA
    reg [15:0] external_pin_drive; // Control de cuándo aplicar datos externos (1=aplicar, 0=alta impedancia)
    
    // Modelado de los pines bidireccionales usando asignación continua
    // Cuando external_pin_drive[i]=1, la entrada externa controla PIN_DATA[i]
    // Cuando external_pin_drive[i]=0, el DUT controla PIN_DATA[i] o es alta impedancia
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : pin_model
            assign PIN_DATA[i] = external_pin_drive[i] ? external_pin_data[i] : 1'bz;
        end
    endgenerate

    // Instancia del módulo a probar (DUT)
    gpio_vector DUT (
        .PIN_DATA(PIN_DATA),
        .clk(clk),
        .reset(reset),
        .Enable(Enable),
        .Function(Function),
        .Data_out(Data_out),
        .Pin_Change_Mask(Pin_Change_Mask),
        .Int_Mask(Int_Mask),
        .Data_in(Data_in),
        .Pin_out(Pin_out),
        .IRQ_PIN_CHANGE(IRQ_PIN_CHANGE),
        .IRQ_INT(IRQ_INT)
    );

    // Generación de la señal de reloj
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Procedimiento de prueba principal
    initial begin
        // Configuración inicial de la simulación
        $dumpfile("gpio_vector_tb.vcd");
        $dumpvars(0, gpio_vector_tb);
        
        // Inicialización de señales
        reset = 1'b1;            // Activar reset
        Enable = 1'b1;           // Deshabilitar módulo (activo en bajo)
        Function = 16'h0000;     // Todos los pines como entrada
        Data_out = 16'h0000;     // Todos los datos de salida en 0
        Pin_Change_Mask = 16'h0000; // Deshabilitar interrupciones
        Int_Mask = 2'b00;        // Tipo de interrupción: ninguna
        external_pin_data = 16'h0000;  // Datos externos en 0
        external_pin_drive = 16'h0000; // No aplicar datos externos
        
        // Esperar un poco y liberar reset
        #(CLK_PERIOD*5);
        reset = 1'b0;
        #(CLK_PERIOD*2);
        
        // PRUEBA 1: Configurar pines mixtos (entrada/salida)
        $display("\n=== PRUEBA 1: Configuración mixta de pines ===");
        Enable = 1'b0;           // Habilitar módulo (activo en bajo)
        Function = 16'hAA55;     // Alternancia: 0=entrada, 1=salida
        Data_out = 16'hFFFF;     // Intentar escribir 1's en todos los pines
        
        // Esperar a que se estabilicen las señales
        #(CLK_PERIOD*5);
        
        // Verificar que los pines de salida muestran los valores correctos
        $display("Verificando pines de salida:");
        $display("Function = %b", Function);
        $display("Pin_out  = %b", Pin_out);
        // Los pines configurados como salida (Function=1) deberían tener Pin_out=1
        
        // PRUEBA 2: Verificar lectura en pines de entrada
        // Aplicar valores externos a los pines configurados como entrada
        $display("\n=== PRUEBA 2: Verificar lectura en pines de entrada ===");
        external_pin_data = 16'h5A5A;  // Patrón alternado
        external_pin_drive = ~Function; // Aplicar solo a pines configurados como entrada
        
        // Esperar a que se estabilicen las señales
        #(CLK_PERIOD*5);
        
        // Verificar que Data_in refleja correctamente las entradas
        $display("Verificando pines de entrada:");
        $display("external_pin_data = %b", external_pin_data);
        $display("external_pin_drive = %b", external_pin_drive);
        $display("Data_in           = %b", Data_in);
        
        // Verificar si cada bit corresponde
        $write("Status pines       : ");
        for(j = 0; j < 16; j = j + 1) begin
            if(external_pin_drive[j] == 1'b1) begin
                if(Data_in[j] == external_pin_data[j])
                    $write("√ ");
                else
                    $write("X ");
            end else begin
                $write("- ");
            end
        end
        $display("");
        
        // PRUEBA 3: Habilitar interrupciones en pines 14 y 15
        $display("\n=== PRUEBA 3: Habilitar interrupciones en pines 14 y 15 ===");
        // Configurar pines 14 y 15 inicialmente como salida
        Function[14] = 1'b1;
        Function[15] = 1'b1;
        Data_out[14] = 1'b1;
        Data_out[15] = 1'b1;
        #(CLK_PERIOD*3);
        
        // Activar detección de interrupciones (flanco de subida)
        Pin_Change_Mask[14] = 1'b1;
        Pin_Change_Mask[15] = 1'b1;
        Int_Mask = 2'b01;        // Detección de flanco de subida
        
        // Simular valores externos (los pines 14 y 15 deben pasar automáticamente a entrada)
        external_pin_drive[15:14] = 2'b11;  // Activar control externo para pines 14 y 15
        external_pin_data[15:14] = 2'b00;   // Iniciar con nivel bajo
        
        #(CLK_PERIOD*5);
        
        // Verificar que los pines 14 y 15 están en modo entrada a pesar de Function=1
        $display("Verificando modo de pines 14 y 15:");
        $display("Function[15:14] = %b", Function[15:14]);
        $display("Pin_out[15:14] = %b", Pin_out[15:14]);
        
        // Generar un flanco de subida en PIN_DATA[14]
        external_pin_data[14] = 1'b1;
        #(CLK_PERIOD*2);
        
        // Verificar señales de interrupción
        $display("Verificando interrupción en pin 14:");
        $display("IRQ_PIN_CHANGE = %b", IRQ_PIN_CHANGE);
        $display("IRQ_INT[0] = %b", IRQ_INT[0]);
        
        // Esperar un poco y generar un flanco de subida en PIN_DATA[15]
        #(CLK_PERIOD*5);
        external_pin_data[15] = 1'b1;
        #(CLK_PERIOD*2);
        
        // Verificar señales de interrupción
        $display("Verificando interrupción en pin 15:");
        $display("IRQ_PIN_CHANGE = %b", IRQ_PIN_CHANGE);
        $display("IRQ_INT[1] = %b", IRQ_INT[1]);
        
        // PRUEBA 4: Cambiar a detección de flanco de bajada
        $display("\n=== PRUEBA 4: Cambiar a detección de flanco de bajada ===");
        Int_Mask = 2'b10;        // Detección de flanco de bajada
        
        // Generar un flanco de bajada en PIN_DATA[14]
        #(CLK_PERIOD*5);
        external_pin_data[14] = 1'b0;
        #(CLK_PERIOD*2);
        
        // Verificar señales de interrupción
        $display("Verificando interrupción en pin 14 (flanco de bajada):");
        $display("IRQ_PIN_CHANGE = %b", IRQ_PIN_CHANGE);
        $display("IRQ_INT[0] = %b", IRQ_INT[0]);
        
        // PRUEBA 5: Verificar reset durante actividad
        $display("\n=== PRUEBA 5: Verificar reset durante actividad ===");
        // Configurar actividad en varios pines
        Function = 16'h5555;     // Mitad como entrada, mitad como salida
        Data_out = 16'hAAAA;     // Patrón alternado para salidas
        external_pin_data = 16'h3333;  // Patrón para entradas
        external_pin_drive = ~Function; // Aplicar solo a pines configurados como entrada
        
        #(CLK_PERIOD*5);
        
        // Aplicar reset
        reset = 1'b1;
        #(CLK_PERIOD*2);
        
        // Verificar que todas las señales se reiniciaron
        $display("Verificando estado después de reset:");
        $display("Data_in = %b (debería ser 0)", Data_in);
        $display("Pin_out = %b (debería ser 0)", Pin_out);
        $display("IRQ_PIN_CHANGE = %b (debería ser 0)", IRQ_PIN_CHANGE);
        $display("IRQ_INT = %b (debería ser 0)", IRQ_INT);
        
        // PRUEBA 6: Verificar deshabilitar módulo (Enable=1)
        $display("\n=== PRUEBA 6: Verificar deshabilitar módulo ===");
        // Liberar reset y configurar
        reset = 1'b0;
        #(CLK_PERIOD*2);
        Function = 16'hFFFF;     // Todos como salida
        Data_out = 16'hFFFF;     // Todos en 1
        Enable = 1'b0;           // Habilitar módulo
        
        #(CLK_PERIOD*5);
        // Verificar que las salidas están activas
        $display("Con Enable=0 (módulo activo):");
        $display("Pin_out = %b", Pin_out);
        
        // Deshabilitar módulo
        Enable = 1'b1;           // Deshabilitar módulo
        #(CLK_PERIOD*5);
        
        // Verificar que las salidas se ponen a 0 cuando se deshabilita el módulo
        $display("Con Enable=1 (módulo inactivo):");
        $display("Pin_out = %b (debería ser 0)", Pin_out);
        
        // Finalizar simulación
        #(CLK_PERIOD*10);
        $display("\nSimulación completada");
        $finish;
    end

endmodule