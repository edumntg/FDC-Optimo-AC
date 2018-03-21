function f = FuncObjetivo(x, LINEDATA, refang, ci, bi, ai, Gik, gi0, Bik, bi0, nb, ng, nl, ns)
    Pg = zeros(ng, 1);
    Pg(1:ng) = x(1:ng);

    f = sum(ci + bi.*Pg + ai.*(Pg.^2));
end