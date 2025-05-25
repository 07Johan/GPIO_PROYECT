module gpio_vector (
    // Señales de interfaz vectorizadas
    inout  wire [15:0] PIN_DATA,       // Vector de datos bidireccionales para todos los pines
    input  wire clk,                   // Señal de reloj (común para todos los pines)
    input  wire reset,                 // Señal de reset (común para todos los pines)
    input  wire Enable,                // Habilitador del módulo (común para todos los pines, activo en bajo)
    input  wire [15:0] Function,       // Vector de configuración: 0=entrada, 1=salida para cada pin
    input  wire [15:0] Data_out,       // Vector de datos de salida para escribir hacia PIN_DATA
    input  wire [15:0] Pin_Change_Mask, // Vector de habilitación de interrupción por cambio para cada pin
    input  wire [1:0] Int_Mask,        // Tipo de interrupción (común para pines 14 y 15)
    output wire [15:0] Data_in,        // Vector de datos leídos desde PIN_DATA
    output wire [15:0] Pin_out,        // Vector de datos escritos al exterior si es salida
    output wire IRQ_PIN_CHANGE,        // Señal global de interrupción por cambio (OR de todas las individuales)
    output wire [1:0] IRQ_INT          // Señales de interrupción para pines 14 y 15
);

    // Señales internas
    wire [15:0] irq_pin_change_vector; // Vector de señales IRQ_PIN_CHANGE individuales
    // Señales especiales para los pines 14 y 15
    wire [1:0] irq_int_vector;         // Vector de señales IRQ_INT para pines 14 y 15
    
    // Señales internas para controlar Function para pines 14 y 15
    wire [15:0] function_internal;     // Función interna que puede ser modificada para pines 14 y 15
    
    // Asignar valores a function_internal:
    // - Para pines 0-13: se usa directamente Function[i]
    // - Para pines 14-15: se usa Function[i] solo si no hay interrupción habilitada
    assign function_internal[13:0] = Function[13:0];
    // Para pin 14: si Pin_Change_Mask[14]=1, forzar a modo entrada (0); si no, usar Function[14]
    assign function_internal[14] = (Pin_Change_Mask[14]) ? 1'b0 : Function[14];
    // Para pin 15: si Pin_Change_Mask[15]=1, forzar a modo entrada (0); si no, usar Function[15]
    assign function_internal[15] = (Pin_Change_Mask[15]) ? 1'b0 : Function[15];
    
    // Instancias de GPIO_Single para cada pin (0-13)
    genvar i;
    generate
        for (i = 0; i < 14; i = i + 1) begin : gpio_pins_0_13
            GPIO_Single gpio_instance (
                .PIN_DATA(PIN_DATA[i]),               // Conexión bidireccional
                .clk(clk),                            // Reloj común
                .reset(reset),                        // Reset común
                .Enable(Enable),                      // Enable común
                .Function(function_internal[i]),      // Función individual
                .Data_out(Data_out[i]),               // Dato de salida individual
                .Pin_Change_Mask(Pin_Change_Mask[i]), // Máscara de cambio individual
                .Int_Mask(2'b00),                     // No importa para pines 0-13, se fija a 0
                .Data_in(Data_in[i]),                 // Dato de entrada individual
                .Pin_out(Pin_out[i]),                 // Estado de salida individual
                .IRQ_PIN_CHANGE(irq_pin_change_vector[i]), // Interrupción de cambio individual
                .IRQ_INT()                            // No se usa para pines 0-13, se deja sin conectar
            );
        end
    endgenerate
    
    // Instancias específicas para pines 14 y 15 (con manejo de IRQ_INT)
    GPIO_Single gpio_instance_14 (
        .PIN_DATA(PIN_DATA[14]),               // Conexión bidireccional
        .clk(clk),                            // Reloj común
        .reset(reset),                        // Reset común
        .Enable(Enable),                      // Enable común
        .Function(function_internal[14]),     // Función controlada internamente
        .Data_out(Data_out[14]),              // Dato de salida
        .Pin_Change_Mask(Pin_Change_Mask[14]), // Máscara de cambio
        .Int_Mask(Int_Mask),                  // Tipo de interrupción
        .Data_in(Data_in[14]),                // Dato de entrada
        .Pin_out(Pin_out[14]),                // Estado de salida
        .IRQ_PIN_CHANGE(irq_pin_change_vector[14]), // Interrupción de cambio
        .IRQ_INT(irq_int_vector[0])           // Interrupción especial para pin 14
    );
    
    GPIO_Single gpio_instance_15 (
        .PIN_DATA(PIN_DATA[15]),               // Conexión bidireccional
        .clk(clk),                            // Reloj común
        .reset(reset),                        // Reset común
        .Enable(Enable),                      // Enable común
        .Function(function_internal[15]),     // Función controlada internamente
        .Data_out(Data_out[15]),              // Dato de salida
        .Pin_Change_Mask(Pin_Change_Mask[15]), // Máscara de cambio
        .Int_Mask(Int_Mask),                  // Tipo de interrupción
        .Data_in(Data_in[15]),                // Dato de entrada
        .Pin_out(Pin_out[15]),                // Estado de salida
        .IRQ_PIN_CHANGE(irq_pin_change_vector[15]), // Interrupción de cambio
        .IRQ_INT(irq_int_vector[1])           // Interrupción especial para pin 15
    );
    
    // Generar señales globales mediante OR
    // IRQ_PIN_CHANGE es el OR de todas las señales individuales IRQ_PIN_CHANGE
    assign IRQ_PIN_CHANGE = |irq_pin_change_vector;
    
    // Conectar las señales IRQ_INT para los pines 14 y 15
    assign IRQ_INT = irq_int_vector;
    
endmodule