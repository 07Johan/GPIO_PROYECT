module GPIO_Single (
    inout  wire PIN_DATA,          // Dato entrante o saliente desde o hacia el entorno
    input  wire clk,               // Señal de reloj
    input  wire reset,             // Señal de reinicio
    input  wire Enable,            // Habilitador del módulo (activo en bajo)
    input  wire Function,          // 0 = entrada, 1 = salida
    input  wire Data_out,          // Dato que se escribe hacia PIN_DATA
    input  wire Pin_Change_Mask,   // Habilita interrupción por cambio
    input  wire [1:0] Int_Mask,    // Tipo de interrupción
    output reg  Data_in,           // Datos leídos desde PIN_DATA
    output reg  Pin_out,           // Dato que se escribe al exterior si es salida
    output reg  IRQ_PIN_CHANGE,    // Señal de activación de cambio de pin
    output reg  IRQ_INT            // Señal de activación de interrupción
);

    // Registros internos
    reg PIN_DATA_prev;             // Almacena el valor previo de PIN_DATA para detectar flancos
    reg pin_direction;             // Registro para almacenar la dirección del pin
    reg pin_value;                 // Valor del pin para salida
    reg irq_detected;              // Señal interna de interrupción detectada
    reg enable_reg;                // Registro para almacenar el estado Enable
    reg function_reg;              // Registro para almacenar el estado Function
    reg pin_change_mask_reg;       // Registro para almacenar el estado Pin_Change_Mask
    reg [1:0] int_mask_reg;        // Registro para almacenar el estado Int_Mask
    
    // Controlar el pin bidireccional
    assign PIN_DATA = (enable_reg == 1'b0 && function_reg == 1'b1) ? pin_value : 1'bz;

//RST ASÍNCRONO
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reiniciar todos los registros
            Data_in <= 1'b0;
            Pin_out <= 1'b0;
            PIN_DATA_prev <= 1'b0;
            pin_direction <= 1'b0;  // Por defecto como entrada
            pin_value <= 1'b0;
            IRQ_PIN_CHANGE <= 1'b0;
            IRQ_INT <= 1'b0;
            irq_detected <= 1'b0;
            // Registros adicionales para guardar el estado de las señales de control
            enable_reg <= 1'b0;
            function_reg <= 1'b0;
            pin_change_mask_reg <= 1'b0;
            int_mask_reg <= 2'b00;
        end else begin
            // Actualizar registros de control
            enable_reg <= Enable;
            function_reg <= Function;
            pin_change_mask_reg <= Pin_Change_Mask;
            int_mask_reg <= Int_Mask;
            
            if (Enable == 1'b0) begin  // Módulo activo cuando Enable = 0
                // Actualizar la dirección del pin basado en Function
                pin_direction <= Function;
                
                // Gestionar modo entrada/salida
                if (Function == 1'b0) begin  // Modo entrada
                    Data_in <= PIN_DATA;     // Leer del pin externo
                    Pin_out <= 1'b0;         // Salida a 0 o alta impedancia
                end else begin              // Modo salida
                    pin_value <= Data_out;   // Escribir al pin externo
                    Pin_out <= Data_out;     // Actualizar también Pin_out
                end
                
                // Gestión de interrupciones (solo en modo entrada)
                if (Function == 1'b0 && pin_change_mask_reg) begin
                    // Detectar flancos
                    case (int_mask_reg)
                        2'b01: begin  // Flanco de subida
                            irq_detected <= (PIN_DATA == 1'b1 && PIN_DATA_prev == 1'b0);
                        end
                        2'b10: begin  // Flanco de bajada
                            irq_detected <= (PIN_DATA == 1'b0 && PIN_DATA_prev == 1'b1);
                        end
                        2'b11: begin  // Cualquier cambio
                            irq_detected <= (PIN_DATA != PIN_DATA_prev);
                        end
                        default: begin  // Interrupciones deshabilitadas
                            irq_detected <= 1'b0;
                        end
                    endcase
                    
                    // Generar pulsos de interrupción si se detecta un flanco
                    if (irq_detected) begin
                        IRQ_PIN_CHANGE <= 1'b1;
                        IRQ_INT <= 1'b1;
                        Data_in <= PIN_DATA;  // Actualizar Data_in con el valor actual del pin
                    end else begin
                        IRQ_PIN_CHANGE <= 1'b0;
                        IRQ_INT <= 1'b0;
                    end
                end else begin
                    IRQ_PIN_CHANGE <= 1'b0;
                    IRQ_INT <= 1'b0;
                    irq_detected <= 1'b0;
                end
                
                // Actualizar el valor previo para la próxima detección de flanco
                PIN_DATA_prev <= PIN_DATA;
            end else begin
                // Módulo inactivo (Enable = 1)
                // CORRECCIÓN: Reiniciar los valores cuando el módulo está deshabilitado
                Pin_out <= 1'b0;   // Resetear Pin_out cuando el módulo está deshabilitado
                IRQ_PIN_CHANGE <= 1'b0;
                IRQ_INT <= 1'b0;
                Data_in <= 1'b0;
            end
        end
    end

endmodule