const SETTING_LABELS = {
    wagersEnabled:   { label: 'Wagers', sub: 'Let hosts put money on a match' },
    killstreaks:     { label: 'Killstreaks', sub: 'UAV, resupply, vest and the death machine' },
    friendlyFire:    { label: 'Friendly fire by default', sub: 'New lobbies start with it on' },
    autoBalance:     { label: 'Auto balance teams', sub: 'Shuffle sides evenly when the match starts' },
    allowSpectators: { label: 'Spectators', sub: 'Anyone can watch a live match' },
    progression:     { label: 'Progression', sub: 'XP, levels and weapon unlocks' },
};

const SETTING_NUMBERS = {
    maxLobbies:    { label: 'Concurrent lobbies', hint: 'Each one runs in its own routing bucket.' },
    houseCut:      { label: 'House cut', hint: 'Share of the pot the house keeps. 0.05 is five percent.', step: '0.01' },
};

async function loadSettings(patch) {
    const result = await nui('settings', patch ? { set: patch } : {});
    if (result && result.ok) APP.settings = result.settings;
    return APP.settings;
}

function renderSettings() {
    const content = document.getElementById('content');
    content.innerHTML = '<div class="empty">Loading settings…</div>';

    loadSettings().then(settings => {
        if (!settings) {
            content.innerHTML = '<div class="empty"><strong>No access</strong>You are not an admin on this server.</div>';
            return;
        }

        content.innerHTML = `
            <div class="row" style="align-items:flex-start;gap:16px">
                <div class="grow">
                    <div class="section-title">Switches</div>
                    <div class="card col" id="setting-toggles" style="gap:8px">
                        ${Object.keys(SETTING_LABELS).map(key =>
                            toggleRow(key, SETTING_LABELS[key].label, SETTING_LABELS[key].sub, settings[key] === true)).join('')}
                    </div>

                    <div class="section-title">Numbers</div>
                    <div class="card">
                        ${Object.keys(SETTING_NUMBERS).map(key => `
                            <div class="field">
                                <label class="field-label">${esc(SETTING_NUMBERS[key].label)}</label>
                                <input type="number" id="set-${key}" value="${settings[key]}" step="${SETTING_NUMBERS[key].step || '1'}">
                                ${SETTING_NUMBERS[key].hint ? `<div class="field-hint">${esc(SETTING_NUMBERS[key].hint)}</div>` : ''}
                            </div>`).join('')}
                        <button class="btn btn-primary" id="btn-save-numbers">Save numbers</button>
                    </div>
                </div>

                <div style="width:320px;flex:0 0 320px">
                    <div class="card">
                        <div class="card-head"><div class="card-title">Where the rest lives</div></div>
                        <div class="field-hint" style="margin:0">
                            Everything else is in config.lua — modes, weapons, killstreak thresholds, the prop list the builder offers,
                            entry points and the arena limits. These switches are the handful worth changing without a restart.
                        </div>
                    </div>

                    <div class="card" style="margin-top:14px">
                        <div class="card-head"><div class="card-title">Killstreaks</div></div>
                        <div class="list">
                            ${(APP.boot.killstreaks || []).map(streak => `
                                <div class="list-row" style="padding:8px 0">
                                    <div class="list-main">
                                        <div class="list-name" style="font-size:12.5px">${esc(streak.label)}</div>
                                        <div class="list-sub">${esc(streak.description || '')}</div>
                                    </div>
                                    <span class="tag accent">${streak.kills}</span>
                                </div>`).join('') || '<div class="field-hint" style="margin:0">Killstreaks are off in the config.</div>'}
                        </div>
                    </div>
                </div>
            </div>`;

        const toggles = document.getElementById('setting-toggles');
        bindToggles(toggles, async (key, on) => {
            const result = await nui('settings', { set: { [key]: on } });
            if (result && result.ok) {
                APP.settings = result.settings;
                toast('Saved', `${SETTING_LABELS[key].label} is now ${on ? 'on' : 'off'}.`, 'success');
            }
        });

        document.getElementById('btn-save-numbers').addEventListener('click', async () => {
            const patch = {};
            Object.keys(SETTING_NUMBERS).forEach(key => {
                patch[key] = numberValue(`set-${key}`, settings[key]);
            });

            const result = await nui('settings', { set: patch });
            if (reportResult(result, 'Saved')) APP.settings = result.settings;
        });
    });
}
