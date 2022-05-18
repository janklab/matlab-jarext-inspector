function [out,fullResults] = listJarExtInfo
%LISTJAREXTINFO Get info about the "external" JARs included with Matlab.
%
% [out,fullResults] = listJarExtInfo
%
% Lists info about all the external (third-party) Java library JARs bundled
% with this distribution of Matlab. This can be used to assess
% compatibility with your own Java code.
%
% This may take a while to run, as it queries external web services for
% information about each JAR file it found.
%
% The info is returned as a table with at least the following variables:
%   * File    - the path of the JAR file, relative to the jarext directory
%   * Title   - the title of the library
%   * Vendor  - the name of the vendor
%   * Version - the version of the library
% The values for any of the columns except File may be blank. All variables
% will be char/cellstr. The fullResults output is a table with even more
% columns, such as:
%   * ImplVer - the implementation version
%   * SpecVer - the specification version
%   * BundleName  - the bundle name
% 
% Returns a table. Also returns fullResults, a table with even more
% columns, whose format is not stable.
%
% Examples:
% 
% jarInfo = listJarExtInfo;
%
% jarInfoXlsxFile = sprintf('jarexts-R%s.xlsx', version('-release'));
% writetable(jarInfo, jarInfoXlsxFile);
%
% % Or view it in Matlab's Workspace widget
%
% See also: CREATEJAREXTREPORT, JAVACLASSPATH

mavenClient = jarext_inspector.MavenCentralRepoClient;

jarextDir = [matlabroot '/java/jarext'];

% Recursively find all JAR files under jarext
files = findFiles(jarextDir);

iJar = 0;
for iFile = 1:numel(files)
    file = files{iFile};    
    if isempty(regexp(file, '\.jar$', 'once'))
        continue
    end
    iJar = iJar + 1;
    File{iJar} = file;
    
    filePath = [jarextDir '/' file];
    jar = java.util.jar.JarFile(filePath);
    manifest = jar.getManifest;
    
    % SHA1 can be used to search Maven Central Repo for unidentified files
    bytes = org.apache.commons.io.FileUtils.readFileToByteArray(...
        java.io.File(filePath));
    Sha1{iJar} = char(org.apache.commons.codec.digest.DigestUtils.shaHex(bytes));
    
    if isempty(manifest)
        attr = containers.Map;
    else
        attribs = manifest.getMainAttributes();

        % Convert the attributes to something we can work with
        attr = containers.Map;
        entries = attribs.entrySet();
        it = entries.iterator();
        while it.hasNext()
            entry = it.next();
            attr(lower(char(entry.getKey().toString()))) = char(entry.getValue());
        end
    end
    jar.close();
        
    BundleName{iJar} = getAttrib(attr, 'bundle-name'); %#ok<*AGROW>
    BundleVendor{iJar} = getAttrib(attr, 'bundle-vendor');
    BundleVer{iJar} = getAttrib(attr, 'bundle-version');
    ImplTitle{iJar} = getAttrib(attr, 'implementation-title');
    ImplVer{iJar} = getAttrib(attr, 'implementation-version');
    ImplVendor{iJar} = getAttrib(attr, 'implementation-vendor');
    SpecTitle{iJar} = getAttrib(attr, 'specification-title');
    SpecVer{iJar} = getAttrib(attr, 'specification-version');
    SpecVendor{iJar} = getAttrib(attr, 'specification-vendor');
    
    % Check our known SHAs
    refShas = knownShas;
    [tf,loc] = ismember(Sha1{iJar}, refShas.Sha1);
    if tf
      refInfo = table2struct(refShas(loc,:));
      ImplTitle{iJar} = refInfo.Title;
      ImplVendor{iJar} = refInfo.Vendor;
      ImplVer{iJar} = refInfo.Version;
    end
    
    % Search Maven Central for more info
    mvn = mavenClient.searchBySha1(Sha1{iJar});
    if mvn.response.numFound == 0
        MavenGroup{iJar} = '';
        MavenArtifact{iJar} = '';
        MavenVersion{iJar} = '';
        MavenRelDate{iJar} = '';
        MavenLatestVer{iJar} = '';
        MavenLatestDate{iJar} = '';
        MavenRecentestVer{iJar} = '';
        MavenRecentestDate{iJar} = '';
    else
        % Use the more official-looking posting of multiple results
        mvnResult = [];
        preferredGroups = { 'commons-codec', 'jdom' };
        for iDoc = 1:mvn.response.numFound
            doc = mvn.response.docs(iDoc);
            if ismember(doc.g, preferredGroups)
                mvnResult = doc;
                break;
            end
        end
        if isempty(mvnResult)
            % Oh well, just use the first
            mvnResult = mvn.response.docs(1);
        end
        MavenGroup{iJar} = mvnResult.g;
        MavenArtifact{iJar} = mvnResult.a;
        MavenVersion{iJar} = mvnResult.v;
        timestamp = datetime(mvnResult.timestamp/1000,...
            'ConvertFrom', 'posixtime');
        MavenRelDate{iJar} = datestr(timestamp, 'yyyy-mm-dd');
        latest = mavenClient.getReportedLatestVersion(MavenGroup{iJar}, MavenArtifact{iJar});
        mostRecent = mavenClient.getMostRecentVersion(MavenGroup{iJar}, MavenArtifact{iJar});
        if isempty(latest)
            MavenLatestVer{iJar} = '';
            MavenLatestDate{iJar} = '';
            MavenRecentestVer{iJar} = '';
            MavenRecentestDate{iJar} = '';
        else
            MavenLatestVer{iJar} = latest.version;
            MavenLatestDate{iJar} = datestr(latest.timestamp, 'yyyy-mm-dd');
            MavenRecentestVer{iJar} = mostRecent.v;
            MavenRecentestDate{iJar} = datestr(mostRecent.timestamp, 'yyyy-mm-dd');
        end
    end
    
    Title{iJar} = firstNonEmptyStr(BundleName{iJar}, ImplTitle{iJar}, ...
        SpecTitle{iJar}, MavenArtifact{iJar});
    Version{iJar} = firstNonEmptyStr(BundleVer{iJar}, ImplVer{iJar}, ...
        SpecVer{iJar}, MavenVersion{iJar});
    Vendor{iJar} = firstNonEmptyStr(BundleVendor{iJar}, ImplVendor{iJar}, ...
        SpecVendor{iJar}, MavenGroup{iJar});
            
end

fullResults = tableFromVectors(File, Title, Version, Vendor, ...
    BundleName, BundleVer, BundleVendor,...
    ImplTitle, ImplVer, ImplVendor, SpecTitle, SpecVer, SpecVendor, Sha1, ...
    MavenGroup, MavenArtifact, MavenVersion, MavenRelDate, MavenLatestVer, MavenLatestDate, ...
    MavenRecentestVer, MavenRecentestDate);
out = fullResults(:,{'Title','Vendor','Version','File','MavenGroup','MavenArtifact', ...
    'MavenVersion','MavenRelDate', ...
    'MavenRecentestVer', 'MavenRecentestDate'});

end

function out = tableFromVectors(varargin)
for i = 1:nargin
    inNames{i} = inputname(i);
end
args = varargin;
for i = 1:numel(args)
    args{i} = args{i}(:);
end
out = table(args{:}, 'VariableNames', inNames);
end

function out = firstNonEmptyStr(varargin)
out = firstNonEmpty(varargin{:});
if isempty(out)
    out = '';
end
end

function out = firstNonEmpty(varargin)
for i = 1:numel(varargin)
    if ~isempty(varargin{i})
        out = varargin{i};
        return;
    end
end
out = [];
end

function out = getAttrib(attr, key)
    if attr.isKey(key)
        out = attr(key);
    else
        out = '';
    end
end

function out = findFiles(file)

if ~isFolder(file)
    error('File %s is not a directory or does not exist', file);
end
out = findFilesStep(file, '');
out = out(:);

end

function out = isFolder(file)
% True if file exists and is a folder
%
% I wrote my own version for compatibility with older Matlabs. Newer Matlabs
% provide isfolder().
jFile = java.io.File(file);
out = jFile.isDirectory;
end

function out = findFilesStep(root, rel)

files = {};
p = [ root '/' rel ];
children = dir(p);
children = { children.name };
for i = 1:numel(children)
    child = children{i};
    childRel = ifthen(isempty(rel), child, [rel '/' child]);
    childPath = [ p '/' child ];
    if ismember(child, {'.' '..'})
        continue
    elseif isFolder(childPath)
        childFiles = findFilesStep(root, childRel);
        files = [files childFiles]; 
    else
        files{end+1} = childRel; 
    end
end

out = files;

end

function out = ifthen(condition, ifValue, elseValue)
if condition
    out = ifValue;
else
    out = elseValue;
end
end

function out = knownShas()
% These are SHA1s that I assembled manually by downloading the distributions and
% running "shasum -a 1" on their JARs.
out = cell2table({
  '1136d197e2755bbde296ceee217ec5fe2917477b', 'Apache Xerces-J', 'Apache', ...
    '2.9.1' 'xercesImpl.jar'
  '90b215f48fe42776c8c7f6e3509ec54e84fd65ef', 'Apache Xerces-J', 'Apache', ...
    '2.9.1' 'xml-apis.jar'
  '9161654d2afe7f9063455f02ccca8e4ec2787222', 'Apache Xerces-J', 'Apache', ...
    '2.10.0' 'xercesImpl.jar'
  '3789d9fada2d3d458c4ba2de349d48780f381ee3', 'Apache Xerces-J', 'Apache', ...
    '2.10.0' 'xml-apis.jar'
  '9bb329db1cfc4e22462c9d6b43a8432f5850e92c', 'Apache Xerces-J', 'Apache', ...
    '2.11.0' 'xercesImpl.jar'
  '3789d9fada2d3d458c4ba2de349d48780f381ee3', 'Apache Xerces-J', 'Apache', ...
    '2.11.0' 'xml-apis.jar'
  'f02c844149fd306601f20e0b34853a670bef7fa2', 'Apache Xerces-J', 'Apache', ...
    '2.12.0' 'xercesImpl.jar'
  '3789d9fada2d3d458c4ba2de349d48780f381ee3', 'Apache Xerces-J', 'Apache', ...
    '2.12.0' 'xml-apis.jar'
  '3a206b25679f598a03374afd4e0410d8849b088b', 'Apache Xerces-J', 'Apache', ...
    '2.12.0' 'xercesImpl.jar'
  '3789d9fada2d3d458c4ba2de349d48780f381ee3', 'Apache Xerces-J', 'Apache', ...
    '2.12.0' 'xml-apis.jar'
  }, 'VariableNames', {'Sha1', 'Title', 'Vendor', 'Version', 'File'});
end