%% geomWriteMitsubaSceneXml
% Writes a minimal Mitsuba XML scene file that references a PLY mesh with ITU radio material.
%
% SYNTAX
%   geomWriteMitsubaSceneXml(filename, plyPathInXml)
%   geomWriteMitsubaSceneXml(filename, plyPathInXml, shapeId)
%   geomWriteMitsubaSceneXml(filename, plyPathInXml, shapeId, materialType)
%   geomWriteMitsubaSceneXml(filename, plyPathInXml, shapeId, materialType, thickness)
%
% INPUT ARGUMENTS
%   filename       (char)  - Output XML file path
%   plyPathInXml   (char)  - Path to PLY mesh file (will be converted to forward slashes)
%   shapeId        (char)  - Shape identifier in XML scene [default: 'scatterers']
%   materialType   (char)  - ITU radio material type for Sionna RT [default: 'concrete']
%   thickness      (float) - Material thickness in scene units, meters [default: 0.2]
%
% DESCRIPTION
%   Creates an XML scene file compatible with Mitsuba 3.0.0 and Sionna RT.
%   The scene includes a path integrator, a single radio material (itu-radio-material),
%   and a PLY mesh shape that references the material.
%   
%   File paths are automatically converted to use forward slashes for cross-platform
%   compatibility, especially on Windows systems.
%
% NOTES
%   - The material type "itu-radio-material" ensures Sionna properly wraps it as
%     RadioMaterialBase with add_object() capability.
%   - Thickness parameter represents material thickness for radio propagation modeling.
%   - Asserts that the output file can be opened for writing.
function geomWriteMitsubaSceneXml(filename, plyPathInXml, shapeId, materialType, thickness)
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
