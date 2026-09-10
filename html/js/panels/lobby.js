function myCitizenId() {
    return (APP.boot && APP.boot.profile && APP.boot.profile.citizenid) || null;
}

function amHost() {
    const lobby = APP.lobby;
    if (!lobby) return false;
    return lobby.host !== undefined && lobby.host === myCitizenId();
}

function myEntry() {
    const lobby = APP.lobby;
    if (!lobby || !lobby.roster) return null;

    const id = myCitizenId();
    return lobby.roster.find(r => r.citizenid === id) || null;
}

function hostSettingsModal() {
    const lobby = APP.lobby;
    const rules = lobby.rules || {};
    const limits = APP.boot.rules;
    const modes = modeOptions();

    modal('Lobby settings', `
        ${field('Lobby name', textInput('set-name', lobby.name))}
        ${field('Game mode', selectInput('set-mode', modes, lobby.mode))}
        ${field('Map', '<select id="set-map"></select>')}
        <div class="row">
            <div class="grow">${field(`Score limit (${limits.scoreLimit.min}-${limits.scoreLimit.max})`, textInput('set-score', rules.scoreLimit, '', 'number'))}</div>
            <div class="grow">${field('Time limit in seconds', textInput('set-time', rules.timeLimit, '', 'number'))}</div>
        </div>
        <div class="row">
            <div class="grow">${field('Respawn delay', textInput('set-respawn', rules.respawnTime, '', 'number'))}</div>
            <div class="grow">${field('Spawn shield', textInput('set-protect', rules.spawnProtect, '', 'number'))}</div>
        </div>
        ${(APP.boot.rounds || []).length > 1
            ? field('Rounds', selectInput('set-rounds',
                APP.boot.rounds.map(n => ({ value: n, label: n === 1 ? 'Single round' : `Best of ${n}` })),
                rules.rounds || 1), 'Sides swap halfway through a best-of.')
            : ''}
        <div class="row">
            <div class="grow">${field('Max players', textInput('set-max', lobby.maxPlayers, '', 'number'))}</div>
            ${APP.boot.wager.enabled ? `<div class="grow">${field('Wager', textInput('set-wager', lobby.wager, '', 'number'))}</div>` : ''}
        </div>
        ${APP.boot.lobbyLimits.passcodes ? field('Passcode', textInput('set-pass', '', lobby.locked ? 'Locked — type to change, blank clears it' : 'Leave empty for an open lobby')) : ''}
        <div id="lobby-toggles">
            ${toggleRow('friendlyFire', 'Friendly fire', 'Paint your own team as well', rules.friendlyFire)}
        </div>
    `, async () => {
        const root = document.getElementById('lobby-toggles');

        const payload = {
            name: value('set-name'),
            mode: value('set-mode'),
            mapId: numberValue('set-map', lobby.mapId),
            maxPlayers: numberValue('set-max', lobby.maxPlayers),
            passcode: APP.boot.lobbyLimits.passcodes ? value('set-pass') : undefined,
            wager: APP.boot.wager.enabled ? numberValue('set-wager', lobby.wager) : undefined,
            rules: {
                scoreLimit: numberValue('set-score', rules.scoreLimit),
                timeLimit: numberValue('set-time', rules.timeLimit),
                respawnTime: numberValue('set-respawn', rules.respawnTime),
                spawnProtect: numberValue('set-protect', rules.spawnProtect),
                rounds: numberValue('set-rounds', rules.rounds || 1),
                friendlyFire: readToggle(root, 'friendlyFire'),
            },
        };

        if (payload.passcode === '' && !lobby.locked) delete payload.passcode;

        const result = await nui('updateLobby', payload);
        return reportResult(result, 'Settings saved') ? undefined : false;
    }, 'Save', 'wide');

    bindToggles(document.getElementById('lobby-toggles'));

    const modeSelect = document.getElementById('set-mode');
    const fill = async (mode) => {
        const result = await nui('mapsFor', { mode });
        const maps = (result && result.maps) || [];
        const select = document.getElementById('set-map');

        select.innerHTML = maps.map(m =>
            `<option value="${m.id}" ${m.id === lobby.mapId ? 'selected' : ''}>${esc(m.name)}</option>`).join('')
            || '<option value="">No map supports this mode</option>';
    };

    modeSelect.addEventListener('change', () => fill(modeSelect.value));
    fill(lobby.mode);
}

function renderLobby() {
    const content = document.getElementById('content');
    const lobby = APP.lobby;

    if (!lobby) {
        content.innerHTML = '<div class="empty"><strong>You are not in a lobby</strong>Head to Play and join one.</div>';
        return;
    }

    const me = myEntry();
    const host = amHost();
    const teams = lobby.teams || [];
    const rules = lobby.rules || {};
    const starting = lobby.state === 'starting';

    document.getElementById('page-sub').textContent =
        `${lobby.modeLabel || lobby.mode} on ${lobby.mapName || 'unknown map'}`;

    document.getElementById('topbar-actions').innerHTML = `
        <span class="tag mono">${esc(lobby.code)}</span>
        ${host ? '<button class="btn btn-sm" id="btn-settings">Settings</button>' : ''}
        <button class="btn btn-sm btn-danger" id="btn-leave">Leave</button>`;

    const groups = teams.length > 0
        ? teams.map(team => ({ team, rows: (lobby.roster || []).filter(r => r.team === team && !r.spectator) }))
        : [{ team: null, rows: (lobby.roster || []).filter(r => !r.spectator) }];

    const spectators = (lobby.roster || []).filter(r => r.spectator);

    content.innerHTML = `
        ${starting ? `
            <div class="countdown-banner" style="margin-bottom:16px">
                Starting in <span class="num">${lobby.countdown}</span>
            </div>` : ''}

        <div class="row" style="align-items:flex-start;gap:16px">
            <div class="grow col">
                <div class="grid ${groups.length > 1 ? 'two' : ''}">
                    ${groups.map(group => `
                        <div class="roster-team">
                            <div class="roster-head ${teamClass(group.team)}">
                                <span>${esc(group.team ? (APP.boot.teams[group.team] || {}).label || group.team : 'Players')}</span>
                                <span>${group.rows.length}</span>
                            </div>
                            ${group.rows.length === 0
                                ? '<div class="roster-row" style="color:var(--ink-3)">Empty</div>'
                                : group.rows.map(row => `
                                <div class="roster-row">
                                    <span class="ready-dot ${row.ready ? 'on' : ''}"></span>
                                    <span class="roster-name">${esc(row.name)}${row.host ? ' <span class="tag muted">host</span>' : ''}${me && row.source === me.source ? '<span class="you">you</span>' : ''}</span>
                                    <span class="tag muted">lvl ${row.level || 1}</span>
                                    ${host && !row.host ? `<button class="btn btn-sm btn-ghost" data-kick="${row.source}">Kick</button>` : ''}
                                </div>`).join('')}
                        </div>`).join('')}
                </div>

                ${spectators.length ? `
                    <div class="card">
                        <div class="card-title">Watching</div>
                        <div class="row wrap" style="gap:6px">
                            ${spectators.map(s => `<span class="tag">${esc(s.name)}</span>`).join('')}
                        </div>
                    </div>` : ''}
            </div>

            <div class="col" style="width:320px;flex:0 0 320px">
                <div class="card">
                    <div class="card-head"><div class="card-title">Rules</div></div>
                    <div class="list">
                        ${lobby.mode === 'hyo'
                            ? '<div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Ends when</div></div><span class="tag mono">a team runs out of lives</span></div>'
                            : `<div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">${esc(lobby.scoreLabel || 'Score')} limit</div></div><span class="tag mono">${rules.scoreLimit}</span></div>`}
                        <div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Time limit</div></div><span class="tag mono">${clock(rules.timeLimit)}</span></div>
                        ${(rules.rounds || 1) > 1
                            ? `<div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Rounds</div></div><span class="tag accent">best of ${rules.rounds}${lobby.round > 1 ? ` &middot; on ${lobby.round}` : ''}</span></div>`
                            : ''}
                        <div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Respawn</div></div><span class="tag mono">${rules.respawnTime}s</span></div>
                        <div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Spawn shield</div></div><span class="tag mono">${rules.spawnProtect}s</span></div>
                        <div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Friendly fire</div></div><span class="tag ${rules.friendlyFire ? 'red' : 'muted'}">${rules.friendlyFire ? 'on' : 'off'}</span></div>
                        ${lobby.wager ? `<div class="list-row" style="padding:8px 0"><div class="list-main"><div class="list-sub">Wager</div></div><span class="tag yellow">${money(lobby.wager)}</span></div>` : ''}
                    </div>
                </div>

                ${teams.length > 0 && !starting ? `
                    <div class="card">
                        <div class="card-head"><div class="card-title">Team</div></div>
                        <div class="row wrap" style="gap:8px">
                            ${teams.map(team => `
                                <button class="btn btn-sm btn-team-${teamClass(team)} ${me && me.team === team ? 'on' : ''}" data-team="${team}">
                                    ${esc((APP.boot.teams[team] || {}).label || team)}
                                </button>`).join('')}
                        </div>
                        <div class="field-hint">You can only move to the smaller side.</div>
                    </div>` : ''}

                <div class="card">
                    <div class="card-head"><div class="card-title">Loadout</div></div>
                    <div class="field-hint" style="margin:0 0 10px">
                        ${me && me.loadout ? esc(Object.values(me.loadout).filter(Boolean).map(weaponLabel).join(' · ')) : 'Nothing picked'}
                    </div>
                    <button class="btn btn-sm btn-block" id="btn-loadout">Change loadout</button>
                </div>

                <button class="btn btn-block ${me && me.ready ? '' : 'btn-primary'}" id="btn-ready" ${starting ? 'disabled' : ''}>
                    ${me && me.ready ? 'Not ready' : 'Ready up'}
                </button>

                ${host ? `<button class="btn btn-block btn-primary" id="btn-start" ${starting ? 'disabled' : ''}>Start match</button>` : ''}
                ${isAdmin() ? `<button class="btn btn-block" id="btn-force" ${starting ? 'disabled' : ''}>Force start</button>` : ''}
            </div>
        </div>`;

    const settings = document.getElementById('btn-settings');
    if (settings) settings.addEventListener('click', hostSettingsModal);

    document.getElementById('btn-leave').addEventListener('click', async () => {
        await nui('leaveLobby');
        APP.lobby = null;
        setTab('play', true);
    });

    document.getElementById('btn-loadout').addEventListener('click', () => setTab('loadout', true));

    document.getElementById('btn-ready').addEventListener('click', async () => {
        await nui('setReady', { ready: !(me && me.ready) });
    });

    const start = document.getElementById('btn-start');
    if (start) {
        start.addEventListener('click', async () => {
            const result = await nui('startMatch');
            reportResult(result, 'Starting', 'Get to your spawn.');
        });
    }

    // Admin only, and the server checks that again. Skips the host check and
    // the player minimum, so a one-player test match works.
    const force = document.getElementById('btn-force');
    if (force) {
        force.addEventListener('click', async () => {
            const result = await nui('startMatch', { force: true });
            reportResult(result, 'Forced start', 'Ignoring the player minimum.');
        });
    }

    content.querySelectorAll('[data-team]').forEach(el => {
        el.addEventListener('click', async () => {
            const result = await nui('setTeam', { team: el.dataset.team });
            reportResult(result);
        });
    });

    content.querySelectorAll('[data-kick]').forEach(el => {
        el.addEventListener('click', async () => {
            const result = await nui('kickPlayer', { source: Number(el.dataset.kick) });
            reportResult(result, 'Removed');
        });
    });
}
