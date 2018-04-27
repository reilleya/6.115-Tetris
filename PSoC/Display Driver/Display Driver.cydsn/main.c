/* ========================================
 *
 * Copyright YOUR COMPANY, THE YEAR
 * All Rights Reserved
 * UNPUBLISHED, LICENSED SOFTWARE.
 *
 * CONFIDENTIAL AND PROPRIETARY INFORMATION
 * WHICH IS THE PROPERTY OF your company.
 *
 * ========================================
*/
#include "project.h"
#include "math.h"

uint8_t back[16];
uint8_t front[16];

uint8_t r = 0;

void rowEnable(uint8_t row){
    spi_1_rck_Write(0);
    spi_1_g_Write(1);
    spi_1_srclr_Write(1);
    SPIM_1_WriteTxData(pow(2, row));
    CyDelay(1);
    spi_1_rck_Write(1);
    spi_1_rck_Write(0);
    spi_1_g_Write(0);
    CyDelay(1);
}

int main(void) {
    CyGlobalIntEnable; /* Enable global interrupts. */

    SPIM_1_Start();
    SPIM_1_EnableTxInt();
    
    SPIM_2_Start();
    SPIM_2_EnableTxInt();

    CyDelay(10);
    
    spi_2_oe_Write(0);
    spi_2_srclr_Write(1);
    spi_2_rck_Write(0);
    CyDelay(10);
    SPIM_2_WriteTxData(0b00010000);
    //CyDelay(1);
    spi_2_rck_Write(1);
    //spi_2_rck_Write(0);
    //spi_2_oe_Write(0);
    CyDelay(1);
    
    for(;;) {
        //led_Write(~led_Read());
        //CyDelay(250);
        
        
        
        rowEnable(r);
        r += 1;
        if(r == 8) r = 0;
    }
}

/* [] END OF FILE */
