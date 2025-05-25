`timescale 1ns / 1ps

module GPIO_Single_tb;

    // Señales para el módulo bajo prueba
    wire PIN_DATA;              // inout
    reg clk;                    // input
    reg reset;                  // input
    reg Enable;                 // input
    reg Function;               // input
    reg Data_out;               // input
    reg Pin_Change_Mask;        // input
    reg [1:0] Int_Mask;         // input
    wire Data_in;               // output
    wire Pin_out;               // output
    wire IRQ_PIN_CHANGE;        // output
    wire IRQ_INT;               // output
    
    // Para simular señales externas en el pin inout
    reg pin_external_driver;    // Para controlar el pin desde "fuera"
    reg pin_external_enable;    // Para habilitar el control externo

    // Asignación bidireccional para simular el entorno externo
    // Solo cuando el módulo no está en modo salida, para evitar conflictos
    assign PIN_DATA = pin_external_enable ? pin_external_driver : 1'bz;
    
    // Señal para monitoreo del PIN_DATA
    wire PIN_DATA_monitor = PIN_DATA;

    // Instancia del módulo bajo prueba
    GPIO_Single uut (
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

    // Generación de reloj
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Reloj de 100MHz (periodo de 10ns)
    end

            // Generación de archivo VCD para gtkwave
    initial begin
        $dumpfile("gpio_single_tb.vcd");
        $dumpvars(0, GPIO_Single_tb);
        // Añadir explícitamente las señales internas para mejor visualización
        $dumpvars(0, uut.function_reg);
        $dumpvars(0, uut.enable_reg);
        $dumpvars(0, uut.pin_change_mask_reg);
        $dumpvars(0, uut.int_mask_reg);
        
        // Configuración inicial del banco de pruebas
        reset = 1;
        Enable = 0;         // Módulo activo
        Function = 0;       // Modo entrada
        Data_out = 0;
        Pin_Change_Mask = 0;
        Int_Mask = 2'b00;
        pin_external_driver = 0;
        pin_external_enable = 0;
        
        #20; // Esperar 20ns
        reset = 0; // Desactivar reset
        #10; // Esperar 10ns

        // Caso de prueba 1: Probar modo entrada (Function = 0)
        $display("Caso de prueba 1: Modo entrada (Function = 0)");
        Function = 0;       // Configurar como entrada
        pin_external_enable = 1; // Habilitar control externo
        #10;
        
        // Probar valores de entrada desde el exterior
        pin_external_driver = 1;
        #20;
        pin_external_driver = 0;
        #20;
        pin_external_driver = 1;
        #20;
        
        // Verificar que Data_in refleja PIN_DATA
        $display("PIN_DATA = %b, Data_in = %b (debería ser igual)", PIN_DATA, Data_in);
        
        // Caso de prueba 2: Probar modo salida (Function = 1)
        $display("Caso de prueba 2: Modo salida (Function = 1)");
        pin_external_enable = 0; // Deshabilitar control externo
        Function = 1;           // Configurar como salida
        #10;
        
        // Probar valores de salida
        Data_out = 0;
        #20;
        Data_out = 1;
        #20;
        Data_out = 0;
        #20;
        
        // Verificar que PIN_DATA y Pin_out reflejan Data_out
        $display("Data_out = %b, PIN_DATA = %b, Pin_out = %b (deberían ser iguales)", Data_out, PIN_DATA, Pin_out);
        
        // Caso de prueba 3: Probar Enable (desactivar módulo)
        $display("Caso de prueba 3: Desactivar módulo (Enable = 1)");
        Enable = 1;         // Desactivar módulo
        Data_out = 1;       // Cambiar salida
        #20;
        
        // Verificar que PIN_DATA está en alta impedancia (Z)
        $display("Enable = %b, PIN_DATA = %b (debería ser Z)", Enable, PIN_DATA);
        
        // Caso de prueba 4: Reactivar módulo
        $display("Caso de prueba 4: Reactivar módulo (Enable = 0)");
        Enable = 0;         // Reactivar módulo
        #20;
        
        // Verificar que PIN_DATA refleja Data_out nuevamente
        $display("Data_out = %b, PIN_DATA = %b (debería ser igual)", Data_out, PIN_DATA);
        
        // Caso de prueba 5: Probar interrupciones - Flanco de subida
        $display("Caso de prueba 5: Interrupción por flanco de subida");
        Function = 0;           // Modo entrada
        Pin_Change_Mask = 1;    // Activar interrupción
        Int_Mask = 2'b01;       // Flanco de subida
        pin_external_enable = 1; // Habilitar control externo
        pin_external_driver = 0; // Iniciar en 0
        #20;
        pin_external_driver = 1; // Cambiar a 1 (flanco de subida)
        #20;
        
        // Verificar interrupción
        $display("IRQ_PIN_CHANGE = %b, IRQ_INT = %b (deberían ser 1 durante un ciclo)", IRQ_PIN_CHANGE, IRQ_INT);
        
        pin_external_driver = 0; // Cambiar a 0 (no debería generar interrupción)
        #20;
        
        // Caso de prueba 6: Probar interrupciones - Flanco de bajada
        $display("Caso de prueba 6: Interrupción por flanco de bajada");
        Int_Mask = 2'b10;       // Flanco de bajada
        pin_external_driver = 1; // Iniciar en 1
        #20;
        pin_external_driver = 0; // Cambiar a 0 (flanco de bajada)
        #20;
        
        // Verificar interrupción
        $display("IRQ_PIN_CHANGE = %b, IRQ_INT = %b (deberían ser 1 durante un ciclo)", IRQ_PIN_CHANGE, IRQ_INT);
        
        // Caso de prueba 7: Probar interrupciones - Cualquier flanco
        $display("Caso de prueba 7: Interrupción por cualquier flanco");
        Int_Mask = 2'b11;       // Cualquier flanco
        #20;
        pin_external_driver = 1; // Cambiar a 1 (flanco de subida)
        #20;
        pin_external_driver = 0; // Cambiar a 0 (flanco de bajada)
        #20;
        
        // Verificar interrupciones
        $display("IRQ_PIN_CHANGE e IRQ_INT deberían activarse en ambos flancos");
        
        // Caso de prueba 8: Deshabilitar interrupciones
        $display("Caso de prueba 8: Deshabilitar interrupciones");
        Pin_Change_Mask = 0;    // Desactivar interrupciones
        
        // Primero, volver a modo entrada para permitir control externo
        Function = 0;
        #10;
        
        // Temporalmente deshabilitar la salida externa para el test
        // para evitar conflictos con el pin inout
        pin_external_enable = 0;
        #10;
        pin_external_enable = 1;
        pin_external_driver = 1; // Cambiar a 1
        #20;
        pin_external_driver = 0; // Cambiar a 0
        #20;
        pin_external_enable = 0; // Deshabilitar control externo
        
        // Verificar que no hay interrupciones
        $display("IRQ_PIN_CHANGE = %b, IRQ_INT = %b (deberían ser 0)", IRQ_PIN_CHANGE, IRQ_INT);
        
        // Caso de prueba 9: Probar interacción entre Function y interrupciones
        $display("Caso de prueba 9: Interacción entre Function y interrupciones");
        Pin_Change_Mask = 1;    // Activar interrupciones
        Int_Mask = 2'b11;       // Cualquier flanco
        Function = 1;           // Modo salida (no debería generar interrupciones)
        Data_out = 1;
        #20;
        Data_out = 0;
        #20;
        
        // Verificar que no hay interrupciones en modo salida
        $display("IRQ_PIN_CHANGE = %b, IRQ_INT = %b (deberían ser 0 en modo salida)", IRQ_PIN_CHANGE, IRQ_INT);
        
        // Caso de prueba 10: Probar Reset
        $display("Caso de prueba 10: Probar Reset");
        
        // Configurar algunas señales a valores distintos de cero
        Function = 1;
        Enable = 0;
        Pin_Change_Mask = 1;
        Int_Mask = 2'b11;
        Data_out = 1;
        #20;
        
        // Activar reset
        reset = 1;
        #20;
        
        // Verificar estado durante el reset
        $display("Durante reset: Function_reg=%b, Enable_reg=%b, Pin_Change_Mask_reg=%b, Int_Mask_reg=%b",
                 uut.function_reg, uut.enable_reg, uut.pin_change_mask_reg, uut.int_mask_reg);
        
        // Desactivar reset
        reset = 0;
        #20;
        
        // Verificar estado después del reset - todos los registros internos deben estar en 0
        $display("Después del reset, todos los registros internos deben estar en 0");
        $display("function_reg=%b, enable_reg=%b, pin_change_mask_reg=%b, int_mask_reg=%b",
                 uut.function_reg, uut.enable_reg, uut.pin_change_mask_reg, uut.int_mask_reg);
        
        // Finalizar simulación
        #100;
        $display("Test bench completado");
        $finish;
    end

endmodule