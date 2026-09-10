function modeOptions() {
    return (APP.boot.modes || []).map(m => ({ value: m.id, label: m.label }));
}

function mapOptions(maps) {
    return (maps || []).map(m => ({ value: m.id, label: m.name }));
}

async function refreshMapSelect(mode) {
    const select = document.getElementById('create-map');
    if (!select) return;

    const result = await nui('mapsFor', { mode });
    const maps = (result && result.maps) || [];

    select.innerHTML = maps.map(m => `<option value="${m.id}">${esc(m.name)}</option>`).join('')
        || '<option value="">No map supports this mode</option>';
}

function createLobbyModal() {
    const boot = APP.boot;
    const modes = modeOptions();

    if (modes.length === 0) {
        toast('No modes', 'Every game mode is switched off in the config.', 'error');
        return;
    }

    const wager = boot.wager || {};

    modal('New lobby', `
        ${field('Lobby name', textInput('create-name', '', 'Friday night scrim'))}
        ${field('Game mode', selectInput('create-mode', modes, modes[0].value))}
        ${field('Map', '<select id="create-map"></select>')}
        <div class="row">
            <div class="grow">${field('Max players', textInput('create-max', boot.lobbyLimits.maxPlayers, '', 'number'))}</div>
            ${wager.enabled ? `<div class="grow">${field('Wager', textInput('create-wager', wager.default || 0, '', 'number'))}</div>` : ''}
        </div>
        ${boot.lobbyLimits.passcodes ? field('Passcode', textInput('create-pass', '', 'Leave empty for an open lobby'), 'Anyone with the code can join a locked lobby.') : ''}
    `, async () => {
        const payload = {
            name: value('create-name'),
            mode: value('create-mode'),
            mapId: numberValue('create-map', 0),
            maxPlayers: numberValue('create-max', boot.lobbyLimits.maxPlayers),
            wager: wager.enabled ? numberValue('create-wager', 0) : 0,
            passcode: value('create-pass', ''),
        };

        const result = await nui('createLobby', payload);
        if (!reportResult(result, 'Lobby open', 'Invite people with the code.')) return false;

        APP.lobby = result.lobby;
        setTab('lobby', true);
    }, 'Create');

    const modeSelect = document.getElementById('create-mode');
    modeSelect.addEventListener('change', () => refreshMapSelect(modeSelect.value));
    refreshMapSelect(modeSelect.value);
}

function joinByCodeModal() {
    modal('Join by code', `
        ${field('Lobby code', textInput('join-code', '', 'ABC12'))}
        ${field('Passcode', textInput('join-pass', '', 'Only if the lobby is locked'))}
    `, async () => {
        const result = await nui('joinLobby', {
            code: value('join-code').trim().toUpperCase(),
            passcode: value('join-pass'),
        });

        if (!reportResult(result, 'Joined')) return false;

        APP.lobby = result.lobby;
        setTab('lobby', true);
    }, 'Join');
}

async function joinLobby(lobby, spectate) {
    if (lobby.locked && !spectate) {
        modal(`Join ${lobby.name}`, field('Passcode', textInput('lobby-pass', '', 'Ask the host')), async () => {
            const result = await nui('joinLobby', { id: lobby.id, passcode: value('lobby-pass') });
            if (!reportResult(result, 'Joined')) return false;

            APP.lobby = result.lobby;
            setTab('lobby', true);
        }, 'Join');
        return;
    }

    const result = await nui('joinLobby', { id: lobby.id, spectate: spectate === true });
    if (!reportResult(result, spectate ? 'Spectating' : 'Joined')) return;

    APP.lobby = result.lobby;

    if (spectate) {
        nui('close');
        closeApp();
    } else {
        setTab('lobby', true);
    }
}

function lobbyCard(lobby) {
    const pct = Math.round((lobby.players / Math.max(1, lobby.max)) * 100);
    const live = lobby.state === 'live';

    return `
        <div class="lobby-card" data-lobby="${lobby.id}">
            <div class="lobby-top">
                <div class="grow">
                    <div class="lobby-name">${esc(lobby.name)}</div>
                    <div class="lobby-meta">${esc(lobby.modeLabel)} &middot; ${esc(lobby.map)} &middot; host ${esc(lobby.host || '-')}</div>
                </div>
                <div style="display:flex;flex-direction:column;gap:4px;align-items:flex-end">
                    <span class="tag ${live ? 'green' : 'accent'}">${live ? 'Live' : lobby.state}</span>
                    ${lobby.locked ? '<span class="tag muted">locked</span>' : ''}
                </div>
            </div>

            <div class="lobby-bar">
                <div class="lobby-fill-track"><div class="lobby-fill" style="width:${pct}%"></div></div>
                <div class="lobby-count">${lobby.players}/${lobby.max}</div>
            </div>

            <div class="row" style="margin-top:12px;gap:8px">
                <span class="tag mono">${esc(lobby.code)}</span>
                ${lobby.wager ? `<span class="tag yellow">${money(lobby.wager)}</span>` : ''}
                ${lobby.spectators ? `<span class="tag muted">${lobby.spectators} watching</span>` : ''}
                <div class="spacer"></div>
                ${live
                    ? `<button class="btn btn-sm" data-spectate="${lobby.id}">Spectate</button>`
                    : `<button class="btn btn-sm btn-primary" data-join="${lobby.id}">Join</button>`}
            </div>
        </div>`;
}

function renderPlay() {
    const content = document.getElementById('content');
    const boot = APP.boot;

    document.getElementById('topbar-actions').innerHTML = `
        ${APP.boot.queue ? `<button class="btn btn-sm ${APP.boot.queue.queued ? 'btn-danger' : ''}" id="btn-queue">${APP.boot.queue.queued ? 'Leave queue' : 'Quick play'}</button>` : ''}
        <button class="btn btn-sm" id="btn-refresh">Refresh</button>
        <button class="btn btn-sm" id="btn-code">Join by code</button>
        <button class="btn btn-sm btn-primary" id="btn-create">New lobby</button>`;

    const waiting = APP.lobbies.filter(l => l.state !== 'live');
    const live = APP.lobbies.filter(l => l.state === 'live');

    content.innerHTML = `
        ${inLobby() ? `
            <div class="card highlight" style="margin-bottom:16px">
                <div class="row" style="align-items:center">
                    <div class="grow">
                        <div class="card-title"><span class="accent">You are in</span> ${esc(APP.lobby.name)}</div>
                        <div class="field-hint">${esc(APP.lobby.modeLabel || '')} on ${esc(APP.lobby.mapName || '')}</div>
                    </div>
                    <button class="btn btn-sm btn-primary" id="btn-goto-lobby">Open lobby</button>
                </div>
            </div>` : ''}

        ${APP.boot.queue && APP.boot.queue.queued ? `
            <div class="card highlight" style="margin-bottom:16px">
                <div class="row" style="align-items:center">
                    <div class="grow">
                        <div class="card-title"><span class="accent">Queued for quick play</span></div>
                        <div class="field-hint">${APP.boot.queue.size} of ${APP.boot.queue.needed} needed. You get dropped into a lobby as soon as there are enough.</div>
                    </div>
                    <button class="btn btn-sm btn-danger" id="btn-queue-leave">Leave queue</button>
                </div>
            </div>` : ''}

        <div class="section-title">Open lobbies</div>
        ${waiting.length === 0
            ? '<div class="empty"><strong>Nothing open right now</strong>Start one and it shows up here for everyone else.</div>'
            : `<div class="grid auto">${waiting.map(lobbyCard).join('')}</div>`}

        ${live.length ? `
            <div class="section-title">Live matches</div>
            <div class="grid auto">${live.map(lobbyCard).join('')}</div>` : ''}

        <div class="section-title">Modes on this server</div>
        <div class="grid auto">
            ${(boot.modes || []).map(mode => `
                <div class="card">
                    <div class="card-title" style="margin-bottom:6px">${esc(mode.label)}</div>
                    <div class="field-hint" style="margin:0">${esc(mode.description)}</div>
                    <div class="row" style="margin-top:10px;gap:6px">
                        <span class="tag">${mode.teams === 0 ? 'Free for all' : `${mode.teams} teams`}</span>
                        <span class="tag muted">to ${mode.scoreLimit}</span>
                    </div>
                </div>`).join('')}
        </div>`;

    document.getElementById('btn-create').addEventListener('click', createLobbyModal);
    document.getElementById('btn-code').addEventListener('click', joinByCodeModal);

    const queueToggle = async (leave) => {
        const result = await nui('queue', leave ? { leave: true } : {});
        if (!reportResult(result, leave ? 'Left the queue' : 'Queued', leave ? '' : 'Hang about here.')) return;

        APP.boot.queue = {
            size: result.size || 0,
            needed: result.needed || (APP.boot.queue && APP.boot.queue.needed) || 2,
            queued: result.queued === true,
        };

        renderPlay();
    };

    const queueBtn = document.getElementById('btn-queue');
    if (queueBtn) queueBtn.addEventListener('click', () => queueToggle(APP.boot.queue.queued));

    const queueLeave = document.getElementById('btn-queue-leave');
    if (queueLeave) queueLeave.addEventListener('click', () => queueToggle(true));

    document.getElementById('btn-refresh').addEventListener('click', async () => {
        const result = await nui('lobbies');
        if (result && result.ok) {
            APP.lobbies = result.lobbies || [];
            renderNav();
            renderPlay();
        }
    });

    const goto = document.getElementById('btn-goto-lobby');
    if (goto) goto.addEventListener('click', () => setTab('lobby', true));

    content.querySelectorAll('[data-join]').forEach(el => {
        el.addEventListener('click', (event) => {
            event.stopPropagation();
            const lobby = APP.lobbies.find(l => String(l.id) === el.dataset.join);
            if (lobby) joinLobby(lobby, false);
        });
    });

    content.querySelectorAll('[data-spectate]').forEach(el => {
        el.addEventListener('click', (event) => {
            event.stopPropagation();
            const lobby = APP.lobbies.find(l => String(l.id) === el.dataset.spectate);
            if (lobby) joinLobby(lobby, true);
        });
    });

    content.querySelectorAll('[data-lobby]').forEach(el => {
        el.addEventListener('click', () => {
            const lobby = APP.lobbies.find(l => String(l.id) === el.dataset.lobby);
            if (lobby) joinLobby(lobby, lobby.state === 'live');
        });
    });
}
