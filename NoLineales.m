function [c, ceq] = NoLineales(x, LINEDATA, refang, ci, bi, ai, Gik, gi0, Bik, bi0, nb, ng, nl, ns)

    c = [];
    ceq = [];
    
    %       Variables de flujos de lineas
    Pik(1:(2*nl)) = x((ng + ng + 1):(ng + ng + 2*nl));
    Qik(1:(2*nl)) = x((ng + ng + 2*nl + 1):(ng + ng + 2*nl + 2*nl));
    
    %       Variables de shunts
    if ns > 0
        Qshunt(1:ns) = x((ng + ng + 2*nl + 2*nl + 1):(ng + ng + 2*nl + 2*nl + ns));
    end

    %       Variables de angulos en barras (sin tomar en cuenta referencia)
    theta = zeros(nb, 1);
    v = 1;
    for i = 1:nb
        if refang(i) == 0
            theta(i) = x((ng + ng + 2*nl + 2*nl + ns) + v);
            v = v + 1;
        end
    end

    %       Variables de voltajes en barras
    V(1:nb) = x((ng + ng + 2*nl + 2*nl + ns + nb - 1 + 1):(ng + ng + 2*nl + 2*nl + ns + nb - 1 + nb));
    
    
    %       Ahora, las ecuaciones de flujos de cada linea
    %       Estas variables estaran ordenadas de igual forma como fueron
    %       definidas las lineas en el archivo RAMAS
    %       Ej: Se define linea from = 1, to = 2, entonces sera la variable
    %       P12 y Q12
    v2 = 1;
    v = 1;
    for l = 1:nl
        i = LINEDATA(l, 1);
        k = LINEDATA(l, 2);
        if i ~= k 
            ceq(v) = Pik(v2) - ((-Gik(i,k) + gi0(i))*V(i)^2 + V(i)*V(k)*(Gik(i,k)*cos(theta(i)-theta(k)) + Bik(i,k)*sin(theta(i)-theta(k))));
            v = v + 1;
            v2 = v2 + 1;
        end
    end
    for l = 1:nl
        i = LINEDATA(l, 2);
        k = LINEDATA(l, 1);
        if i ~= k 
            ceq(v) = Pik(v2) - ((-Gik(i,k) + gi0(i))*V(i)^2 + V(i)*V(k)*(Gik(i,k)*cos(theta(i)-theta(k)) + Bik(i,k)*sin(theta(i)-theta(k))));
            v = v + 1;
            v2 = v2 + 1;
        end
    end
    
    v2 = 1;
    for l = 1:nl
        i = LINEDATA(l, 1);
        k = LINEDATA(l, 2);
        if i ~= k 
            ceq(v) = Qik(v2) - ((Bik(i,k) - bi0(i))*V(i)^2 + V(i)*V(k)*(-Bik(i,k)*cos(theta(i)-theta(k)) + Gik(i,k)*sin(theta(i)-theta(k))));
            v = v + 1;
            v2 = v2 + 1;
        end
    end
    
    for l = 1:nl
        i = LINEDATA(l, 2);
        k = LINEDATA(l, 1);
        if i ~= k 
            ceq(v) = Qik(v2) - ((Bik(i,k) - bi0(i))*V(i)^2 + V(i)*V(k)*(-Bik(i,k)*cos(theta(i)-theta(k)) + Gik(i,k)*sin(theta(i)-theta(k))));
            v = v + 1;
            v2 = v2 + 1;
        end
    end
    
    % Finalmente, las ecuaciones de cada shunt
    if ns > 0
        v2 = 1;
        for l = 1:nl+ns
            i = LINEDATA(l, 1);
            k = LINEDATA(l, 2);
            if i == k % es un shunt
                Z = LINEDATA(l, 3) + 1i*LINEDATA(l, 4);

%                 ceq(v) = Qshunt(v2) - conj(Z)\V(i)^2;
                ceq(v) = Qshunt(v2) - imag((V(i)^2)/conj(Z));
                v = v + 1;
                v2 = v2 + 1;
            end
        end
    end
end