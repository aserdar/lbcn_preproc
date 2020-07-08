function basic_stim_features = get_basic_features(data, task)

switch task
    case 'MMR'
        basic_stim_features = data.trialinfo.condNames;
    case 'VTCLoc'
        basic_stim_features = data.trialinfo.condNames;
        if sum(~isnan(data.trialinfo.oneback)) > 0
            basic_stim_features{end+1} = 'oneback';
        else
        end
end


for i = 1:length(basic_stim_features)
    bsf_tmp =  strsplit(basic_stim_features{i}, '-');
    if length(bsf_tmp) == 2
        basic_stim_features(i) = {[bsf_tmp{1} '_' bsf_tmp{2}]};
    else
    end
end

features = unique(basic_stim_features);
basic_stim_features = table(features);

end
