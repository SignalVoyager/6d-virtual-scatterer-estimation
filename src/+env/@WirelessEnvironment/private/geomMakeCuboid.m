% =========== helper: write ASCII PLY ===========
function [F,V] = geomMakeCuboid(scatterTable)
% geomMakeCuboid - convert one [x y z w d h] box row to mesh faces/vertices.
% Outputs triangular faces F and vertex coordinates V.
x0 = scatterTable(1); y0 = scatterTable(2); z0 = scatterTable(3);
w  = scatterTable(4); d  = scatterTable(5); h  = scatterTable(6); 
x1 = x0 + w; y1 = y0 + d; z1 = z0+h;
V = [ x0, y0, z0;
      x1, y0, z0;
      x1, y1, z0;
      x0, y1, z0;
      x0, y0, z1;
      x1, y0, z1;
      x1, y1, z1;
      x0, y1, z1 ];
F = [1 2 3; 1 3 4;   % bottom
     5 8 7; 5 7 6;   % top
     1 5 6; 1 6 2;   % side 1
     2 6 7; 2 7 3;   % side 2
     3 7 8; 3 8 4;   % side 3
     4 8 5; 4 5 1];  % side 4
end
