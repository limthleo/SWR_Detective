function unpack_struct(struct)
% unpack_struct - Unpacks the fields of a structure into the MATLAB base workspace.
%
%   This function takes a structure as input and assigns each of its fields 
%   as a separate variable in the base workspace. The field names of the structure
%   are used as variable names, and the corresponding field values are assigned to them.
%
%   Inputs:
%   - struct : A structure containing fields to be unpacked. The structure can have any 
%             number of fields, and each field can contain any type of data.

fields = fieldnames(struct);  % Get the names of the fields in the structure

for f = 1:length(fields)
    % For each field, assign its value to a variable in the base workspace
    assignin('base', fields{f}, struct.(fields{f}));
end

end
