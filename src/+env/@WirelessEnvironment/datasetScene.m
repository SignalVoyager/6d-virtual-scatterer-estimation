function datasetScene(obj, mode)
% datasetScene - prepare scene files (STL/PLY/XML) for ray tracing backends.
% mode:
%   "save" - build mesh from scatterTable and write STL/PLY/XML.
%   "load" - read existing STL from stlFile and regenerate PLY/XML.

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
