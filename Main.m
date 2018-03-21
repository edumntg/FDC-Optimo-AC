%   Flujo de carga optimo AC mediante fmincon
%   En este flujo de carga los flujos de lineas se establecen como
%   variables

clc, clear all;

% [BUSDATA, LINEDATA, GENDATA] = LoadData('DATOS_Wollenberg.xlsx', 'BUS', 'RAMAS', 'GEN');
% [BUSDATA, LINEDATA, GENDATA] = LoadData('DATOS_MarioPereira.xlsx', 'BUS', 'RAMAS', 'GEN');
[BUSDATA, LINEDATA, GENDATA] = LoadData('DATOS_3b_3g.xlsx', 'BUS', 'RAMAS', 'GEN');

nb = size(BUSDATA, 1);
ng = size(GENDATA, 1);
nl = size(LINEDATA, 1);

% contemos los shunts
ns = 0;
for i = 1:nl
    if LINEDATA(i, 1) == LINEDATA(i, 2) % si i == k significa que es un shunt
        ns = ns + 1;
    end
end

% Ya que no queremos contar los shunts como lineas, debemos restar este
% valor al numero total de lineas
nl = nl - ns;

[Ybus, Gik, Bik, gi0, bi0] = CreateYbus(LINEDATA, nb, nl);

Pload = BUSDATA(:, 6);
Qload = BUSDATA(:, 7);
Pgen = BUSDATA(:, 8);
Qgen = BUSDATA(:, 9);

ci = GENDATA(:, 2);
bi = GENDATA(:, 3); %Cmg
ai = GENDATA(:, 4);

Pgmin = GENDATA(:, 5);
Pgmax = GENDATA(:, 6);
Qgmin = GENDATA(:, 7);
Qgmax = GENDATA(:, 8);

for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Pflowmax(i, 1) = LINEDATA(i, 7);
    end
end
% Pflowmax = LINEDATA(:, 7);
for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Qflowmax(i, 1) = LINEDATA(i, 8);
    end
end
% Qflowmax = LINEDATA(:, 8);
if ns > 0
    v = 1;
    for i = 1:nl+ns
        from = LINEDATA(i, 1);
        to = LINEDATA(i, 2);
        if from == to % es shunt
            Qshuntmax(v, 1) = LINEDATA(i, 8);
            v = v + 1;
        end
    end
end

Pflowmax(Pflowmax >= 1e10) = Inf;       % Si se declara un maximo >= 1e10, se asigna como infinito
Qflowmax(Qflowmax >= 1e10) = Inf;       % Si se declara un maximo >= 1e10, se asigna como infinito
if ns > 0
    Qshuntmax(Qshuntmax >= 1e10) = Inf;       % Si se declara un maximo >= 1e10, se asigna como infinito
end

refang = BUSDATA(:, 3);

Vmin = BUSDATA(:, 18);
Vmax = BUSDATA(:, 19);

%%      

%       Las matrices como vectores tendran (ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb)  columnas

%       Esto corresponde a 'ng + ng Potencias generadas', '4 variables por
%       cada linea 2*nl + 2*nl (4 flujos por linea (Pik Pki Qik Qki)', 'ns' corresponde a cuantos shunts
%       hay en el sistema. 'nb - 1 variables por barra (nb - 1 angulos como incognitas de angulos) y nb voltajes

%       La matriz Aeq tendra nb filas y (ng + ng + 2*nl + 2*nl + nb - 1 + nb) columnas
%       Pues sera una ecuacion por cada barra con generador (ecuaciones
%       lineales)
%       Por ahora no se toma en cuenta ecuaciones de potencia reactiva

% Aeq = zeros(2*nb, (ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb));
beq = zeros(2*nb, 1);

Amq = zeros(2*nb, 2*ng);

v = 1;
for i = 1:ng        % correspondiente a los terminos Pgi
    Amq(v,v) = 1;
    v = v + 1;
end

v = 1;
for i = 1:ng        % correspondiente a los terminos Qgi
    Amq(nb + v, ng + v) = 1;
    v = v + 1;
end

Bmq = zeros(2*nb, 4*nl);
Cmq = zeros(2*nb, nb - 1);
Dmq = zeros(2*nb, nb);

%       Llenamos la matriz Bmq con los terminos correspondientes a las
%       variables de flujos de lineas correspondientes a cada ecuacion de
%       potencia generada
%       Pgi = P12 + P12 + ... Pik + Ploadi
%       Pgi - P12 - P13 - ... Pik = Ploadi
%       Qgi = Q12 + Q12 + ... Qik + Qloadi
%       Qgi - Q12 - Q13 - ... Qik = Qloadi

v = 1;
for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Bmq(from, v) = -1;
        v = v + 1;
    end
end
for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Bmq(to, v) = -1;
        v = v + 1;
    end
end

v = 2*nl + 1;
for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Bmq(nb + from, v) = -1;
        v = v + 1;
    end
end
for i = 1:nl
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from ~= to
        Bmq(nb + to, v) = -1;
        v = v + 1;
    end
end

% Vector correspondiente a las variables de los shunts
% Si existen compensadores en el sistema, se agrega una columna adicional a
% la matriz Bmq
for i = 1:nl+ns
    from = LINEDATA(i, 1);
    to = LINEDATA(i, 2);
    if from == to %% corresponde a un shunt
        Bmq(nb + from, 2*nl + 2*nl + 1) = -1;
    end
end

Aeq = [Amq Bmq Cmq Dmq];
beq(1:nb) = Pload(1:nb);
beq(nb+1:2*nb) = Qload(1:nb);

A = [];
b = [];
 
%       Se establecen los limites inferiores y superiores (lb y ub)
lb = Pgmin;
lb = vertcat(lb, Qgmin);
lb = vertcat(lb, -Pflowmax);
lb = vertcat(lb, -Pflowmax);

lb = vertcat(lb, -Qflowmax);
lb = vertcat(lb, -Qflowmax);
if ns > 0
    lb = vertcat(lb, -Qshuntmax);
end

lb = vertcat(lb, -ones(nb - 1, 1).*Inf);
lb = vertcat(lb, Vmin);

ub = Pgmax;
ub = vertcat(ub, Qgmax);
ub = vertcat(ub, Pflowmax);
ub = vertcat(ub, Pflowmax);

ub = vertcat(ub, Qflowmax);
ub = vertcat(ub, Qflowmax);
if ns > 0
    ub = vertcat(ub, Qshuntmax);
end

ub = vertcat(ub, ones(nb - 1, 1).*Inf);
ub = vertcat(ub, Vmax);

%       Vector de valores iniciales
x0 = zeros(1, (ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb));
x0((ng + ng + 2*nl + 2*nl + ns + nb - 1 + 1):(ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb)) = BUSDATA(1:nb, 4);

options = optimset('display', 'on', 'algorithm', 'interior-point'); 
[x,fval,exitflag,~,lambda] = fmincon('FuncObjetivo', x0, A, b, Aeq, beq, lb, ub, 'NoLineales', options, LINEDATA, refang, ci, bi, ai, Gik, gi0, Bik, bi0, nb, ng, nl, ns);
exitflag

Pg = x(1:ng);
Pgen = Pg;
Pgen(ng+1:nb) = 0;
Qg = x((ng + 1):(ng + ng));
Qgen = Qg;
Qgen(ng+1:nb) = 0;
Pik = x((ng + ng + 1):(ng + ng + nl));
Pki = x((ng + ng + nl + 1):(ng + ng + 2*nl));
Qik = x((ng + ng + 2*nl + 1):(ng + ng + 2*nl + nl));
Qki = x((ng + ng + 2*nl + nl + 1):(ng + ng + 2*nl + 2*nl));

theta = zeros(nb, 1);
v = 1;
for i = 1:nb
    if refang(i) == 0
        theta(i) = x((ng + ng + 2*nl + 2*nl + ns) + v);
        v = v + 1;
    end
end

V = x((ng + ng + 2*nl + 2*nl + ns + nb - 1 + 1):(ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb));

Ploss = sum(Pik) + sum(Pki);
Qloss = sum(Qik) + sum(Qki);

% Sshunt = zeros(nb, 1);
% for l = 1:nl
%     i = LINEDATA(l, 1);
%     k = LINEDATA(l, 2);
%     if i == k% es shunt
%         Zshunt = LINEDATA(l, 3) + 1i*LINEDATA(l, 4);
%         Sshunt(i) = V(i)^2 /Zshunt;
%     end
% end
Sshunt = zeros(nb, 1);
if ns > 0
    v = 1;
    for i = 1:nl+ns
        from = LINEDATA(i, 1);
        to = LINEDATA(i, 2);
        if from == to
            Sshunt(from) = x(ng + ng + 2*nl + 2*nl + v);
            v = v + 1;
        end
    end
end

Pneta = Pgen' - Pload;
Qneta = Qgen' - Qload - Sshunt;

lamb = abs(lambda.eqlin);

%Kuhn-Tucker
eta = abs(lambda.lower);
miu = abs(lambda.upper);

Costo_generacion = sum(ci + bi.*Pg' + ai.*Pg'.^2);
Cobro_transmision = sum(eta((ng + ng + 1):(ng + ng + nl)).*Pik') + ...
                    sum(eta((ng + ng + nl + 1):(ng + ng +nl + nl)).*Pki') + ...
                    sum(miu((ng + ng + 1):(ng + ng + nl)).*Pik') + ...
                    sum(miu((ng + ng + nl + 1):(ng + ng +nl + nl)).*Pki');
                
PrintFCO(V, theta, Pgen, Qgen, Pload, Qload, Ploss, Qloss, Pneta, Qneta, Sshunt, Pik, Pki, Pflowmax, Costo_generacion, LINEDATA, nb, nl);

% lambda.eqnonlin
% lambda.ineqlin
% lambda.upper
% lambda.lower