function geomWriteMitsubaSceneXml(filename, plyPathInXml, shapeId, materialType, thickness)
% geomWriteMitsubaSceneXml - write a minimal Mitsuba XML scene referencing a PLY mesh.
% The XML includes one ITU radio material used by Sionna RT.
if nargin < 3 || isempty(shapeId)
    shapeId = 'scatterers';
end
if nargin < 4 || isempty(materialType)
    materialType = 'concrete';   % Sionna ITU material type
end
if nargin < 5 || isempty(thickness)
    thickness = 0.2;             % meters (or scene unit)
end

% Make path XML-friendly (especially on Windows)
plyPathInXml = char(plyPathInXml);
plyPathInXml = strrep(plyPathInXml, '\', '/');

fid = fopen(filename, 'w');
assert(fid>0, 'Cannot open XML file for writing: %s', filename);

fprintf(fid, '<scene version="3.0.0">\n');
fprintf(fid, '  <integrator type="path"/>\n\n');

% --- Sionna RT radio material (critical) ---
% Use itu-radio-material so that Sionna wraps it as RadioMaterialBase (has add_object()).
fprintf(fid, '  <bsdf type="itu-radio-material" id="mat0">\n');
fprintf(fid, '    <string name="type" value="%s"/>\n', materialType);
fprintf(fid, '    <float name="thickness" value="%.6g"/>\n', thickness);
fprintf(fid, '  </bsdf>\n\n');

% --- Geometry ---
fprintf(fid, '  <shape type="ply" id="%s">\n', shapeId);
fprintf(fid, '    <string name="filename" value="%s"/>\n', plyPathInXml);
fprintf(fid, '    <ref id="mat0"/>\n');
fprintf(fid, '  </shape>\n');

fprintf(fid, '</scene>\n');

fclose(fid);
end
