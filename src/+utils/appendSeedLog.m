function appendSeedLog(logFile, expName, seed, seedStart, tailLine, bodyText)
fid = fopen(logFile, "a");
assert(fid > 0, "Cannot open log file: %s", logFile);

fprintf(fid, "\n================ EXP: %s | SEED: %d ================\n", expName, seed);
fprintf(fid, "[START] %s\n", seedStart);

bodyStr = string(bodyText);
bodyStr = bodyStr(:);
bodyStr = bodyStr(~ismissing(bodyStr) & strlength(bodyStr) > 0);
if ~isempty(bodyStr)
    fprintf(fid, "%s\n", char(strjoin(bodyStr, newline)));
end

fprintf(fid, "%s", tailLine);
fclose(fid);
end
