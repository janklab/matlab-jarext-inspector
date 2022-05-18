function createJarExtReport
% Create a jarext report file and view it.
%
% See also: LISTJAREXTINFO

fprintf('\n');
fprintf('Matlab %s on %s\n', version, computer);
jarextDir = [matlabroot '/java/jarext'];

jarInfo = listJarExtInfo;

fprintf('Found %d JAR libs in Matlab''s jarext dir at %s.\n', size(jarInfo,1), jarextDir);
jarInfoXlsxFile = sprintf('jarexts-R%s.xlsx', version('-release'));
if isfile(jarInfoXlsxFile)
    delete(jarInfoXlsxFile);
end
writetable(jarInfo, jarInfoXlsxFile);
fprintf('Wrote report to: %s\n', jarInfoXlsxFile);

if ispc
    winopen(jarInfoXlsxFile)
else
    open(jarInfoXlsxFile)
end

end