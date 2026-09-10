const APP = {
    boot: null,
    tab: 'play',
    lobby: null,
    lobbies: [],
    maps: [],
    editor: null,
    stats: null,
    settings: null,
    loadout: null,
};

const PAGES = {
    play:     { title: 'Play',     sub: 'Join a lobby or start your own',   render: () => renderPlay() },
    lobby:    { title: 'Lobby',    sub: 'Teams, rules and the ready check', render: () => renderLobby() },
    loadout:  { title: 'Loadout',  sub: 'Pick what you carry into a match', render: () => renderLoadout() },
    unlocks:  { title: 'Unlocks',  sub: 'Kits and tints you have earned',   render: () => renderUnlocks() },
    maps:     { title: 'Maps',     sub: 'Build and manage arenas',          render: () => renderMaps(), admin: true },
    editor:   { title: 'Builder',  sub: 'Place everything in the world',    render: () => renderEditor(), admin: true, hidden: true },
    stats:    { title: 'Stats',    sub: 'Your record and the leaderboard',  render: () => renderStats() },
    settings: { title: 'Settings', sub: 'Server-wide paintball options',    render: () => renderSettings(), admin: true },
};

function isAdmin() {
    return APP.boot && APP.boot.isAdmin === true;
}

function inLobby() {
    return APP.lobby !== null && APP.lobby !== undefined;
}

function navItems() {
    const items = [
        { id: 'play', label: 'Play' },
        { id: 'lobby', label: 'Lobby', hidden: !inLobby() },
        { id: 'loadout', label: 'Loadout' },
        { id: 'unlocks', label: 'Unlocks' },
        { id: 'maps', label: 'Maps', admin: true },
        { id: 'stats', label: 'Stats' },
        { id: 'settings', label: 'Settings', admin: true },
    ];

    return items.filter(item => !item.hidden && (!item.admin || isAdmin()));
}

function renderNav() {
    const host = document.getElementById('nav');

    host.innerHTML = navItems().map(item => `
        <button class="nav-item ${APP.tab === item.id ? 'active' : ''}" data-tab="${item.id}">
            <span>${esc(item.label)}</span>
            ${item.id === 'play' && APP.lobbies.length ? `<span class="nav-count">${APP.lobbies.length}</span>` : ''}
            ${item.id === 'lobby' && APP.lobby && APP.lobby.roster ? `<span class="nav-count">${APP.lobby.roster.length}</span>` : ''}
        </button>`).join('');

    host.querySelectorAll('[data-tab]').forEach(el => {
        el.addEventListener('click', () => setTab(el.dataset.tab));
    });
}

function renderLevel() {
    const profile = APP.boot && APP.boot.profile;
    if (!profile) return;

    document.getElementById('level-badge').textContent = profile.level || 1;
    document.getElementById('level-name').textContent = profile.name || 'Player';
    document.getElementById('level-xp').textContent = `${profile.xp || 0} / ${profile.levelNext || 0} XP`;
    document.getElementById('level-fill').style.width = `${profile.levelPct || 0}%`;
}

function setTab(tab, force) {
    const page = PAGES[tab];
    if (!page) return;
    if (page.admin && !isAdmin()) return;
    if (APP.tab === tab && !force) { renderPage(); return; }

    // Leaving the builder any other way than its own Close button still has to
    // put the ghost props away.
    if (APP.tab === 'editor' && tab !== 'editor') {
        nui('builderClose');
        APP.editor = null;
    }

    APP.tab = tab;
    renderNav();
    renderPage();
}

function renderPage() {
    const page = PAGES[APP.tab] || PAGES.play;

    document.getElementById('page-title').textContent = page.title;
    document.getElementById('page-sub').textContent = page.sub;
    document.getElementById('topbar-actions').innerHTML = '';

    page.render();
}

function refresh() {
    renderNav();
    renderLevel();
    renderPage();
}

async function reload() {
    const boot = await nui('bootstrap');
    if (boot && boot.ok) {
        APP.boot = boot;
        APP.lobbies = boot.lobbies || [];
        APP.lobby = boot.lobby || null;
        refresh();
    }
}

function openApp(payload) {
    APP.boot = payload.boot;
    APP.lobbies = (payload.boot && payload.boot.lobbies) || [];
    APP.lobby = payload.lobby || (payload.boot && payload.boot.lobby) || null;
    APP.loadout = null;

    document.getElementById('app').classList.remove('hidden');
    document.getElementById('app').classList.remove('suspended');

    let tab = payload.tab || (inLobby() ? 'lobby' : 'play');

    if (payload.builder && isAdmin()) {
        APP.editor = { map: payload.builder, check: null };
        tab = 'editor';
    }

    if (PAGES[tab] && PAGES[tab].admin && !isAdmin()) tab = 'play';

    APP.tab = tab;
    refresh();

    if (tab === 'editor') editorSync();
}

function closeApp() {
    document.getElementById('app').classList.add('hidden');
    closeModal();
}

function renderHost(data) {
    const root = document.getElementById('host-root');

    if (!data) { root.innerHTML = ''; root.classList.add('hidden'); return; }

    const others = (data.roster || []).filter(r => r.source !== data.self && !r.spectator);

    root.innerHTML = `
        <div class="host-backdrop">
            <div class="host-panel">
                <div class="host-head">
                    <div>
                        <div class="host-title">Host controls</div>
                        <div class="host-sub">${esc(data.mode || '')} &middot; ${esc(data.map || '')}${(data.rounds || 1) > 1 ? ` &middot; round ${data.round} of ${data.rounds}` : ''}</div>
                    </div>
                    <button class="modal-close" id="host-x">&times;</button>
                </div>

                <div class="host-actions">
                    <button class="btn btn-danger btn-block" data-host="end">End the match now</button>
                    <button class="btn btn-block" data-host="restart">Restart this round</button>
                    ${(data.teams || []).length > 1 ? '<button class="btn btn-block" data-host="swap">Swap sides now</button>' : ''}
                    ${(data.maps || []).length > 1 ? `
                        <div class="field" style="margin:4px 0 0">
                            <label class="field-label">Next map</label>
                            <select id="host-map">
                                ${data.maps.map(m => `<option value="${m.id}">${esc(m.name)}</option>`).join('')}
                            </select>
                            <div class="field-hint">Takes effect on the next round or match.</div>
                        </div>
                        <button class="btn btn-block" id="host-setmap">Set next map</button>` : ''}
                </div>

                <div class="host-list">
                    ${others.length === 0
                        ? '<div class="field-hint" style="padding:12px 16px;margin:0">Nobody else in here.</div>'
                        : others.map(row => `
                        <div class="host-row">
                            <span class="team-dot ${row.alive ? 'talking' : ''}"></span>
                            <span class="host-name">${esc(row.name)}</span>
                            <span class="tag muted">${row.kills || 0}k</span>
                            <button class="btn btn-sm btn-danger" data-kick="${row.source}">Kick</button>
                        </div>`).join('')}
                </div>

                <div class="host-foot">F7 closes this</div>
            </div>
        </div>`;

    root.classList.remove('hidden');

    const close = () => { nui('hostClose'); renderHost(null); };
    document.getElementById('host-x').addEventListener('click', close);

    const setMap = document.getElementById('host-setmap');
    if (setMap) {
        setMap.addEventListener('click', async () => {
            const result = await nui('hostAction', { action: 'map', mapId: numberValue('host-map', 0) });
            reportResult(result, 'Next map set');
        });
    }

    root.querySelectorAll('[data-host]').forEach(el => {
        el.addEventListener('click', async () => {
            const result = await nui('hostAction', { action: el.dataset.host });
            if (!reportResult(result, 'Done')) return;
            if (el.dataset.host === 'end') close();
        });
    });

    root.querySelectorAll('[data-kick]').forEach(el => {
        el.addEventListener('click', async () => {
            const result = await nui('hostAction', { action: 'kick', source: Number(el.dataset.kick) });
            if (reportResult(result, 'Removed')) el.closest('.host-row').remove();
        });
    });
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (typeof message.action === 'string' && message.action.startsWith('hud:')) {
        hudHandle(message.action.slice(4), message.data);
        return;
    }

    switch (message.action) {
        case 'open':
            openApp(message.data || {});
            break;

        case 'close':
            closeApp();
            break;

        case 'suspend':
            document.getElementById('app').classList.toggle('suspended', message.data === true);
            break;

        case 'queue':
            if (APP.boot) {
                APP.boot.queue = message.data
                    ? { size: message.data.size, needed: message.data.needed, queued: true }
                    : { size: 0, needed: (APP.boot.queue && APP.boot.queue.needed) || 2, queued: false };
            }
            if (APP.tab === 'play') renderPage();
            break;

        case 'host': renderHost(message.data || null); break;

        case 'lobbyList':
            APP.lobbies = message.data || [];
            if (APP.tab === 'play') renderPage();
            renderNav();
            break;

        case 'lobbyState':
            APP.lobby = message.data || null;
            if (!APP.lobby && APP.tab === 'lobby') {
                setTab('play');
            } else if (APP.tab === 'lobby' || APP.tab === 'play') {
                renderPage();
            }
            renderNav();
            break;
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;

    if (document.getElementById('modal-root').innerHTML !== '') {
        closeModal();
        return;
    }

    if (!document.getElementById('host-root').classList.contains('hidden')) {
        nui('hostClose');
        renderHost(null);
        return;
    }

    if (!document.getElementById('app').classList.contains('hidden')) {
        nui('close');
        closeApp();
    }
});

document.getElementById('btn-close').addEventListener('click', () => {
    nui('close');
    closeApp();
});
