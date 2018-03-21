%% Carga de datos de barras y lineas desde archivo dat
function [BUSDATA, LINEDATA, GENDATA] = LoadData(file, bussheet, linesheet, gensheet)
%     BUSDATA = load(busfile, '-ascii');
%     LINEDATA = load(linefile, '-ascii');
%     GENDATA = load(genfile, '-ascii');
    BUSDATA = xlsread(file, bussheet);
    LINEDATA = xlsread(file, linesheet);
    GENDATA = xlsread(file, gensheet);
end