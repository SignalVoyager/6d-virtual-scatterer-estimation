%% datasetScene
% Prepares scene files (STL/PLY/XML) for ray tracing backends by either
% building a mesh from a scatter table or loading an existing STL file.
%
% SYNTAX:
%   datasetScene(obj)
%   datasetScene(obj, mode)
%
% INPUTS:
%   obj     - WirelessEnvironment object containing SceneSpec properties
%   mode    - (optional) Character vector or string specifying operation mode
%             • "save" (default) - Build mesh from scatterTable and write STL/PLY/XML
%             • "load"           - Read existing STL from stlFile and regenerate PLY/XML
%
% OUTPUTS:
%   None (writes files to disk)
%
% DETAILS:
%   This method generates three scene description files required for ray 
%   tracing simulation:
%   - STL file: 3D mesh geometry containing cuboid scatterers
%   - PLY file: ASCII point cloud representation of the mesh
%   - XML file: Mitsuba scene configuration with material properties
%
%   In "save" mode, cuboid geometries are constructed from rows in scatterTable
%   and combined into a single mesh before writing to STL format.
%
%   In "load" mode, an existing STL file is read and processed to regenerate
%   the PLY and XML files. Supports both triangulation objects and struct outputs
%   from stlread().
%
% DEPENDENCIES:
%   • geomMakeCuboid  - Creates cuboid mesh geometry
%   • stlwrite        - Writes triangulation to STL file
%   • stlread         - Reads STL file
%   • geomWritePlyAscii - Writes ASCII PLY format
%   • geomWriteMitsubaSceneXml - Generates Mitsuba XML scene
%
% ERRORS:
%   • Unknown mode: Raised if mode is neither "save" nor "load"
%   • STL file not found: Raised in load mode if stlFile does not exist
%   • Unsupported stlread output: Raised if STL data format is unrecognized
%
% EXAMPLE:
%   datasetScene(envObj, "save");   % Generate new scene files
%   datasetScene(envObj, "load");   % Regenerate from existing STL
function datasetScene(obj, mode)
if nargin < 2 || strlength(string(mode)) == 0
    mode = "save";
end
mode = lower(string(mode));

scattererTable = obj.SceneSpec.scatterTable;
plyFile = obj.SceneSpec.plyFile;
xmlFile = obj.SceneSpec.xmlFile;
stlFile = obj.SceneSpec.stlFile;

switch mode
    case "save"
        fprintf('  [datasetScene] Building mesh from scatterTable ...\n');
        [F,V] = deal([]);
        for k = 1:size(scattererTable,1)
            [f,v] = geomMakeCuboid(scattererTable(k,:));
            F = [F; f + size(V,1)]; %#ok<AGROW>
            V = [V; v]; %#ok<AGROW>
        end

        stlwrite(triangulation(F,V), stlFile);
        fprintf('  [datasetScene] STL file saved: %s\n', stlFile);

    case "load"
        fprintf('  [datasetScene] Loading existing STL: %s\n', stlFile);
        if ~isfile(stlFile)
            error('datasetScene: STL file not found in load mode: %s', stlFile);
        end

        stlData = stlread(stlFile);
        if isa(stlData, "triangulation")
            F = stlData.ConnectivityList;
            V = stlData.Points;
        elseif isstruct(stlData) && isfield(stlData, "faces") && isfield(stlData, "vertices")
            F = stlData.faces;
            V = stlData.vertices;
        else
            error('datasetScene: Unsupported stlread output type for file: %s', stlFile);
        end

    otherwise
        error('datasetScene: Unknown mode "%s". Use "save" or "load".', mode);
end

geomWritePlyAscii(plyFile, V, F);
fprintf('  [datasetScene] PLY saved:   %s\n', plyFile);

geomWriteMitsubaSceneXml(xmlFile, string(plyFile), "scatterers", "concrete", 0.2);
fprintf('  [datasetScene] XML saved:   %s\n', xmlFile);
end
