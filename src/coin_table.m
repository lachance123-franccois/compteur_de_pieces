function T = coin_table()
% COIN_TABLE Renvoie les caractéristiques officielles des pièces en euros.
%
%   Sortie :
%       T : Structure contenant les tables de référence officielles :
%           T.names      : Noms affichables des pièces
%           T.values     : Valeurs faciales en euros
%           T.diamMm     : Diamètres officiels en millimètres
%           T.material   : Nature du métal ou agencement bimétallique
%           T.innerRatio : Rapport du diamètre du coeur sur le diamètre total

    T.names      = {'1 c', '2 c', '5 c', '10 c', '20 c', '50 c', '1 €', '2 €'};
    T.values     = [0.01 0.02 0.05 0.10 0.20 0.50 1 2];
    T.diamMm     = [16.25 18.75 21.25 19.75 22.25 24.25 23.25 25.75];
    T.material   = {'cuivre', 'cuivre', 'cuivre', 'or', 'or', 'or', 'bi1', 'bi2'};
    T.innerRatio = [0 0 0 0 0 0 16.25/23.25 18.75/25.75];
end
