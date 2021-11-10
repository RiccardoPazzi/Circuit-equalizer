----------------------------------------------------------------------------------
--Politecnico di Milano, Italia
-- studente: Riccardo Pazzi
-- anno: 2020/2021
-- No Matricola: 890980
-- Prova finale di reti logiche
----------------------------------------------------------------------------------

--Librerie necessarie
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--Entity del progetto
entity project_reti_logiche is
port (
i_clk : in std_logic;
i_rst : in std_logic;
i_start : in std_logic;
i_data : in std_logic_vector(7 downto 0);
o_address : out std_logic_vector(15 downto 0);
o_done : out std_logic;
o_en : out std_logic;
o_we : out std_logic;
o_data : out std_logic_vector (7 downto 0)
);
end project_reti_logiche;


architecture Behavioral of project_reti_logiche is
type state_type is(
    START, -- Stato Iniziale Della Macchina
    MEM_ACCESS, --Stato nel quale si attende operazioni di accesso a memoria (READ/WRITE)
    READ_X, --Leggo la larghezza (in byte) dell'immagine
    READ_Y, --Leggo l'altezza in byte dell'immagine
    FIND_MIN_MAX, --Trova massimo e minimo valore dei pixel e li salva in (min)max_value
    PROCESS_PIXEL, --Calcola il pixel dell'immagine equalizzata e prepara la scrittura
    PREPARE_PIXEL, --Prepara la lettura del pixel da equalizzare e controlla se la FSM ha finito
    DONE, -- Porta il segnale o_done a 1
    DONE_WAIT -- Attende un segnale di start a 0, dopodichè porta Done a 0 e riporta la fsm allo stato iniziale
    );
    
signal STATE, P_STATE : state_type; --STATE contiene lo stato attuale mentre P_STATE contiene lo stato precedente
begin
    process(i_clk, i_rst)
 
 
 
 --------------------------------------------------------------------------------------------
-- Variabili Utilizzate
--------------------------------------------------------------------------------------------
variable delta_value: integer range 0 to 255; -- pixel_max - pixel_min
variable shift_level: integer range 0 to 8;
variable temp_pixel: std_logic_vector(7 downto 0); --Pixel temporaneo per le letture
variable temp_value: std_logic_vector(15 downto 0); --Valore temporaneo per calcolo new_pixel
variable current_pixel_value: std_logic_vector(7 downto 0); --Pixel letto da equalizzare
variable new_pixel_value: std_logic_vector(7 downto 0); --Pixel equalizzato
variable address: std_logic_vector(15 downto 0); --Indirizzo di lettura
variable write_address: std_logic_vector(15 downto 0); --Indirizzo di scrittura
variable min_value: std_logic_vector(7 downto 0); --Minimo valore di pixel nell'immagine (0-255)
variable max_value: std_logic_vector(7 downto 0); --Massimo valore di pixel nell'immagine (0-255)
variable image_width: std_logic_vector(7 downto 0);
variable image_height: std_logic_vector(7 downto 0);
variable number_of_cells: integer range 0 to 65025; -- image_width * image_height, numero di celle occupate in memoria dall'immagine
--variable distance_from_min: integer range 0 to 255;

begin 


--------------------------------------------------------------------------------------------
-- Architecture Progetto Reti Logiche
--------------------------------------------------------------------------------------------


    if(i_rst = '1') then -- Reset di stato e variabili
        --report "--------RESET--------"; 
        --Riporto i segnali a valore iniziale
        o_en <= '0';
        o_we <= '0';
        o_done <= '0';  
        --Riporto gli stati al valore iniziale
        P_STATE <= START;
        STATE <= START;  
    
    
    elsif(rising_edge(i_clk)) then -- Se è passato un ciclo di clock e sono sul fronte di salita
        case STATE is           -- Definiamo gli stati
                 when START =>
                 if (i_start = '1' AND i_rst = '0') then                                                      
                    o_address <= x"0000";  -- indirizzo di partenza
                    o_en <= '1';
                    o_we <= '0';
                    min_value := "11111111";
                    max_value := "00000000";
                    address := x"0002"; --Inizio dalla cella 3 a leggere
                    write_address := x"0000";
                    STATE <= MEM_ACCESS;     -- stato dove voglio andare
                    P_STATE <= START;      -- stato dove mi trovo adesso "Present State";
                end if; 
                
                when READ_X=>
                   image_width := i_data;
                   o_address <= x"0001";
                   P_STATE <= READ_X;
                   STATE <= MEM_ACCESS;
                   
                when READ_Y=>
                    image_height := i_data;
                    number_of_cells := TO_INTEGER(unsigned(image_width)) * TO_INTEGER(unsigned(image_height));
                    if(number_of_cells = 0) then
                    --Controllo di sicurezza sul numero di celle
                        STATE<=DONE;
                    else
                    o_address <= x"0002";
                    P_STATE <= READ_Y;
                    STATE <= MEM_ACCESS;
                    end if;
                
                when FIND_MIN_MAX=>
                    temp_pixel := i_data;
                    if(TO_INTEGER(unsigned(address)) < (number_of_cells + 1)) then
                        if(TO_INTEGER(unsigned(temp_pixel)) > TO_INTEGER(unsigned(max_value))) then
                            max_value := temp_pixel;
                        end if;
                        if(TO_INTEGER(unsigned(temp_pixel)) < TO_INTEGER(unsigned(min_value))) then
                            min_value := temp_pixel;
                        end if;
                        address := address + x"0001";
                        o_address <= address;
                        P_STATE<=FIND_MIN_MAX;
                        STATE<=MEM_ACCESS;
                    else
                        address := x"0001"; -- Setto l'inidirizzo nuovamente al primo pixel da leggere
                        --o_address <= address;
                        --Write address viene incrementato ad ogni PROCESS_PIXEL per questo assegno l'indirizzo che voglio (n_of_cells + 2) ma con - 1
                        write_address:= std_logic_vector(to_unsigned(number_of_cells + 1, write_address'length)); --Setto il primo indirizzo di scrittura
                        STATE<=PREPARE_PIXEL;
                    end if;
                    
               when MEM_ACCESS=>
                    --Regola i vari passaggi di stato ed usa il ciclo di clock come buffer per lasciar lavorare la memoria
                    --Così non rischio di leggere prima che le uscite siano aggiornate al valore finale
                    if(P_STATE = START)then
                        STATE <= READ_X;
                    elsif(P_STATE = READ_X) then
                        STATE <= READ_Y;
                    elsif(P_STATE = READ_Y) then
                        STATE <= FIND_MIN_MAX;
                    elsif(P_STATE = FIND_MIN_MAX) then
                        -- Posso lasciare lo stato attuale in MIN_MAX finchè non passo a process pixel?
                        STATE <= FIND_MIN_MAX;
                    elsif(P_STATE = PROCESS_PIXEL) then
                        STATE <= PREPARE_PIXEL;
                    elsif(P_STATE = PREPARE_PIXEL) then
                        STATE <= PROCESS_PIXEL;
                    else
                        STATE <= DONE;   --Sistema basic di correzione degli errori, se non riconosco lo stato tra questi riparto dall'inizio
                    end if;
                    
              when PROCESS_PIXEL =>
                    current_pixel_value := i_data; --In ingresso ho il valore del pixel che sto leggendo
                    --Algoritmo per calcolare il nuovo pixel equalizzato
                    delta_value:= TO_INTEGER(unsigned(max_value)) - TO_INTEGER(unsigned(min_value));
                    if(delta_value = 0) then
                        shift_level := 8;
                    elsif(delta_value >= 1 and delta_value < 3) then
                        shift_level := 7;
                    elsif(delta_value >= 3 and delta_value < 7) then
                        shift_level := 6;
                    elsif(delta_value >= 7 and delta_value < 15) then
                        shift_level := 5;
                    elsif(delta_value >= 15 and delta_value < 31) then
                        shift_level := 4;
                    elsif(delta_value >= 31 and delta_value < 63) then
                        shift_level := 3;
                    elsif(delta_value >= 63 and delta_value < 127) then
                        shift_level := 2;
                    elsif(delta_value >= 127 and delta_value < 255) then
                        shift_level := 1;
                    else
                        shift_level := 0;
                    end if;
                    
                    temp_value := std_logic_vector(shift_left(unsigned("00000000"&current_pixel_value) - unsigned("00000000"&min_value),shift_level));
                    
                    if(TO_INTEGER(unsigned(temp_value)) > 255) then
                        new_pixel_value := "11111111"; --Setto il valore del pixel in scrittura a 255
                        --report "--------overflow--------"; 
                    else
                        new_pixel_value := temp_value(7 downto 0); --Setto il valore del pixel uguale agli ultimi 8 bit di temp_value
                    end if;
                    
                    --Preparo la memoria per la scrittura e le uscite
                    o_we <= '1';
                    write_address:= write_address + x"0001";
                    o_address <= write_address;
                    o_data <= new_pixel_value;
                    --Attendo un ciclo di clock per l'accesso con MEM_ACCESS
                    P_STATE <= PROCESS_PIXEL;
                    STATE <= MEM_ACCESS;
                    
                    
              when PREPARE_PIXEL =>
                    --Dopo aver scritto il pixel preparo la memoria per la lettura ed il seguente processing
                    o_we <= '0';
                    --Controllo di fine processing, se address supera il numero di celle non vado alla prossima (numero_celle + 2)
                    if(TO_INTEGER(unsigned(address)) > number_of_cells) then
                        STATE <= DONE;
                    else
                        address := address + x"0001";
                        o_address <= address;
                        P_STATE <= PREPARE_PIXEL;
                        STATE <= MEM_ACCESS;
                    end if;
               
              when DONE =>
                o_en <= '0'; -- Disabilito la lettura
                o_we <= '0'; -- Disabilito la scrittura
                o_done <= '1'; -- Alzo il segnale di Done
                STATE <= DONE_WAIT; 
                
                
              when DONE_WAIT =>
                if(i_start = '0') then -- Attendo che start si abbassi per abbassare il done
                    o_done <= '0'; -- Abbasso il Done
                    P_STATE <= START; -- Torno allo stato iniziale
                    STATE <= START; -- Torno Allo stato iniziale
                end if;
                
         end case;
      end if;                
  end process;
end Behavioral;
