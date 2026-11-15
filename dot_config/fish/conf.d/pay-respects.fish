# Pay Respects Fish Integration (Auto-command correction via 'f')
if status is-interactive
    if type -q pay-respects
        pay-respects fish --alias f | source
    end
end
