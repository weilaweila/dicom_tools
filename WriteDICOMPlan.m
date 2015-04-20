function varargout = WriteDICOMPlan(plan, file)
% WriteDICOMPlan saves the provided dose array to a DICOM RTPlan file. If
% the patient demographics (name, ID, etc) are not included in the plan
% structure, the user will be prompted to provide them.
%
% The following variables are required for proper execution: 
%   plan: structure containing the calculated plan information. See
%       tomo_extract/LoadPlan() for more information on the format of this
%       structure.
%   file: string containing the path and name to write the DICOM 
%       RTDOSE file to. MATLAB must have write access to this location to 
%       execute successfully.
%
% The following variables are returned upon successful completion:
%   varargout{1} (optional): RT plan SOP instance UID
%
% Below is an example of how this function is used:
%
%   % Look for plans within a patient archive
%   plans = FindPlans('/path/to/archive', 'name_patient.xml');
%
%   % Load the first plan
%   plan = LoadPlan('/path/to/archive', 'name_patient.xml', plans{1});
%
%   % Execute WriteDICOMPlan
%   dest = '/file/to/write/plan/to/RTplan.dcm';
%   WriteDICOMPlan(plan, dest);
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Check if MATLAB can find dicomwrite (Image Processing Toolbox)
if exist('dicomwrite', 'file') ~= 2
    
    % If not, throw an error
    if exist('Event', 'file') == 2
        Event(['The Image Processing Toolbox cannot be found and is ', ...
            'required by this function.'], 'ERROR');
    else
        error(['The Image Processing Toolbox cannot be found and is ', ...
            'required by this function.']);
    end
end

% Execute in try/catch statement
try
    
% Log start of DVH computation and start timer
if exist('Event', 'file') == 2
    Event(['Writing dose to DICOM RTPlan file ', file]);
    tic;
end

% Initialize dicominfo structure with FileMetaInformationVersion
info.FileMetaInformationVersion = [0;1];

% Specify transfer syntax and implementation UIDs
info.TransferSyntaxUID = '1.2.840.10008.1.2';
info.ImplementationClassUID = '1.2.40.0.13.1.1';
info.ImplementationVersionName = 'dcm4che-2.0';
info.SpecificCharacterSet = 'ISO_IR 100';

% Specify class UID as RTPlan
info.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.481.5';
info.SOPClassUID = info.MediaStorageSOPClassUID;
info.Modality = 'RTPLAN';

% Specify unique instance UID (this will be overwritten by dicomwrite)
info.MediaStorageSOPInstanceUID = dicomuid;
info.SOPInstanceUID = info.MediaStorageSOPInstanceUID;

% Generate creation date/time
if isfield(plan, 'timestamp')
    t = plan.timestamp;
else
    t = now;
end

% Specify creation date/time
info.InstanceCreationDate = datestr(t, 'yyyymmdd');
info.InstanceCreationTime = datestr(t, 'HHMMSS');

% Specify acquisition date/time
info.StudyDate = datestr(t, 'yyyymmdd');
info.StudyTime = datestr(t, 'HHMMSS');

% Specify manufacturer, model, and software version
info.Manufacturer = ['MATLAB ', version];
info.ManufacturerModelName = 'WriteDICOMPlan';
info.SoftwareVersion = '1.1';

% Specify series description (optional)
if isfield(plan, 'seriesDescription')
    info.SeriesDescription = plan.seriesDescription;
else
    info.SeriesDescription = '';
end

% Specify study description (optional)
if isfield(plan, 'studyDescription')
    info.StudyDescription = plan.studyDescription;
else
    info.StudyDescription = '';
end

% Specify patient info (assume that if name isn't provided, nothing is
% provided)
if isfield(plan, 'patientName')
    
    % If name is a structure
    if isstruct(plan.patientName)
        
        % Add name from provided dicominfo
        info.PatientName = plan.patientName;
        
    % Otherwise, if name is a char array
    elseif ischar(plan.patientName)
        
        % Add name to family name
        info.PatientName.FamilyName = plan.patientName;
    
    % Otherwise, throw an error
    else
        if exist('Event', 'file') == 2
            Event('Provided patient name is an unknown format', 'ERROR');
        else
            error('Provided patient name is an unknown format');
        end
    end
    
    % Specify patient ID
    if isfield(plan, 'patientID')
        info.PatientID = plan.patientID;
    else
        info.PatientID = '';
    end
    
    % Specify patient birthdate
    if isfield(plan, 'patientBirthDate')
        info.PatientBirthDate = plan.patientBirthDate;
    else
        info.PatientBirthDate = '';
    end
    
    % Specify patient sex
    if isfield(plan, 'patientSex')
        info.PatientSex = upper(plan.patientSex(1));
    else
        info.PatientSex = '';
    end
    
    % Specify patient age
    if isfield(plan, 'patientAge')
        info.PatientAge = plan.patientAge;
    else
        info.PatientAge = '';
    end
    
% If a valid screen size is returned (MATLAB was run without -nodisplay)
elseif usejava('jvm') && feature('ShowFigureWindows')
    
    % Prompt user for patient name
    input = inputdlg({'Family Name', 'Given Name', 'ID', 'Birth Date', ...
        'Sex', 'Age'}, 'Provide Patient Demographics', ...
        [1 50; 1 50; 1 30; 1 30; 1 10; 1 10]); 
    
    % Add provided input
    info.PatientName.FamilyName = char(input{1});
    info.PatientName.GivenName = char(input{2});
    info.PatientID = char(input{3});
    info.PatientBirthDate = char(input{4});
    info.PatientSex = char(input{5});
    info.PatientAge = char(input{6});
    
    % Clear temporary variables
    clear input;
    
% Otherwise, no data was provided and no UI exists to prompt user
else
    
    % Add generic data
    info.PatientName.FamilyName = 'DOE';
    info.PatientName.GivenName = 'J';
    info.PatientID = '00000000';
    info.PatientBirthDate = '';
    info.PatientSex = '';
    info.PatientAge = '';
end

% Specify study UID
if isfield(plan, 'studyUID')
    info.StudyInstanceUID = plan.studyUID;
else
    info.StudyInstanceUID = dicomuid;
end

% Specify unique series UID
info.SeriesInstanceUID = dicomuid;

% Specify position reference indicator
info.PositionReferenceIndicator = 'OM';

% Specify frame of reference UID
if isfield(plan, 'frameRefUID')
    info.FrameOfReferenceUID = plan.frameRefUID;
else
    info.FrameOfReferenceUID = dicomuid;
end

% Specify plan label
if isfield(plan, 'planLabel')
    info.RTPlanLabel = plan.planLabel;
else
    info.RTPlanLabel = '';
end

% Specify plan date/time
if isfield(plan, 'timestamp')
    info.InstanceCreationDate = datestr(plan.timestamp, 'yyyymmdd');
    info.InstanceCreationTime = datestr(plan.timestamp, 'HHMMSS');
end

% Specify plan geometry
info.RTPlanGeometry = 'PATIENT';

% Specify prescription summary
if isfield(plan, 'rxDose') && isfield(plan, 'rxVolume')
    info.PrescriptionDescription = sprintf(['%0.1f%% of the prescription', ...
        ' volume receives at least %0.1f Gy'], plan.rxVolume, plan.rxDose);
end

% Specify number of fractions
if isfield(plan, 'fractions')
    info.FractionGroupSequence.Item_1.FractionGroupNumber = 1;
    info.FractionGroupSequence.Item_1.NumberOfFractionsPlanned = ...
        plan.fractions;
    info.FractionGroupSequence.Item_1.NumberOfBeams = 1;
    info.FractionGroupSequence.Item_1.NumberOfBrachyApplicationSetups = 0;
    
    % Specify fraction prescription dose
    if isfield(plan, 'rxDose')
        info.FractionGroupSequence.Item_1.ReferencedBeamSequence.Item_1...
            .BeamMeterset = 1;
        info.FractionGroupSequence.Item_1.ReferencedBeamSequence.Item_1...
            .ReferencedBeamNumber = 1;
        info.FractionGroupSequence.Item_1.ReferencedDoseReferenceSequence...
            .Item_1.TargetPrescriptionDose = plan.rxDose;
    end
end

% Specify beam sequence information
if isfield(plan, 'machine') && isfield(plan, 'planType')
    info.BeamSequence.Item_1.Manufacturer = 'TomoTherapy Incorporated';
    info.BeamSequence.Item_1.ManufacturerModelName = 'Hi-Art';
    info.BeamSequence.Item_1.TreatmentMachineName = plan.machine;
    info.BeamSequence.Item_1.PrimaryDosimeterUnit = 'MINUTE';
    info.BeamSequence.Item_1.SourceAxisDistance = 850;
    info.BeamSequence.Item_1.BeamName = ...
        [plan.planType, ' TomoTherapy Beam'];
    info.BeamSequence.Item_1.RadiationType = 'PHOTON';
    info.BeamSequence.Item_1.TreatmentDeliveryType = 'TREATMENT';
    info.BeamSequence.Item_1.NumberOfWedges = 0;
    info.BeamSequence.Item_1.NumberOfCompensators = 0;
    info.BeamSequence.Item_1.NumberOfBoli = 0;
    info.BeamSequence.Item_1.NumberOfBlocks = 0;
    info.BeamSequence.Item_1.FinalCumulativeMetersetWeight = 1;
    info.BeamSequence.Item_1.ReferencedPatientSetupNumber = 1;
end

% Specify patient setup
if isfield(plan, 'position')
    info.PatientSetupSequence.Item_1.PatientPosition = plan.position;
    info.PatientSetupSequence.Item_1.PatientSetupNumber = 1;
    info.PatientSetupSequence.Item_1.SetupTechnique = 'ISOCENTRIC';
end

% Specify referenced structure set
if isfield(plan, 'structureSetUID')
    info.ReferencedStructureSetSequence.Item_1.ReferencedSOPClassUID = ...
        '1.2.840.10008.5.1.4.1.1.481.3';
    info.ReferencedStructureSetSequence.Item_1.ReferencedSOPInstanceUID = ...
        plan.structureSetUID;
end

% Specify referenced dose image
if isfield(plan, 'doseSeriesUID')
    info.ReferencedDoseSequence.Item_1.ReferencedSOPClassUID = ...
        '1.2.840.10008.5.1.4.1.1.481.2';
    info.ReferencedDoseSequence.Item_1.ReferencedSOPInstanceUID = ...
        plan.doseSeriesUID;
end

% Specify approval information
if isfield(plan, 'approver') && isfield(plan, 'timestamp')
    info.ApprovalStatus = 'APPROVED';
    info.ReviewDate = datestr(plan.timestamp, 'yyyymmdd');
    info.ReviewTime = datestr(plan.timestamp, 'HHMMSS');
    info.ReviewerName = plan.approver;
end
    
% Write DICOM file using dicomwrite()
status = dicomwrite([], file, info, 'CompressionMode', 'None', 'CreateMode', ...
    'Copy', 'Endian', 'ieee-le');

% If the UID is to be returned
if nargout == 1
   
    % Load the dicom file back into info
    info = dicominfo(file);
    
    % Return UID
    varargout{1} = info.SOPInstanceUID;
    
    % Log UID
    if exist('Event', 'file') == 2
        Event(['SOPInstanceUID set to ', info.SOPInstanceUID]);
    end
end

% Check write status
if isempty(status)
    
    % Log completion of function
    if exist('Event', 'file') == 2
        Event(sprintf(['DICOM RTPlan export completed successfully in ', ...
            '%0.3f seconds'], toc));
    end
    
% If not empty, warn user of any errors
else
    
    % Log completion of function
    if exist('Event', 'file') == 2
        Event(sprintf(['DICOM RTPlan export completed with one or more ', ...
            'warnings in %0.3f seconds'], toc), 'WARN');
    else
        warning('DICOM RTPlan export completed with one or more warnings');
    end
end


% Clear temporary variables
clear info t status;

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end