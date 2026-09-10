const STATS = { scope: 'all', sortBy: 'kills' };

async function loadStats() {
    const result = await nui('stats', { scope: STATS.scope, sortBy: STATS.sortBy, limit: 15 });
    if (result && result.ok) APP.stats = result;
    return APP.stats;
}

function renderStats() {
    const content = document.getElementById('content');
    content.innerHTML = '<div class="empty">Reading the record books…</div>';

    loadStats().then(() => {
        const data = APP.stats || {};
        const profile = data.profile || {};
        const board = data.leaderboard || [];
        const history = data.history || [];

        document.getElementById('topbar-actions').innerHTML = `
            ${data.weekly ? `
                <button class="btn btn-sm ${STATS.scope === 'all' ? 'btn-primary' : ''}" data-scope="all">All time</button>
                <button class="btn btn-sm ${STATS.scope === 'weekly' ? 'btn-primary' : ''}" data-scope="weekly">This week</button>` : ''}`;

        content.innerHTML = `
            <div class="grid four" style="margin-bottom:18px">
                <div class="stat-tile"><div class="stat-value">${profile.kills || 0}</div><div class="stat-label">Kills</div></div>
                <div class="stat-tile"><div class="stat-value">${profile.deaths || 0}</div><div class="stat-label">Deaths</div></div>
                <div class="stat-tile"><div class="stat-value">${ratio(profile.kills, profile.deaths)}</div><div class="stat-label">K / D</div></div>
                <div class="stat-tile"><div class="stat-value">${profile.wins || 0}</div><div class="stat-label">Wins</div></div>
            </div>

            <div class="grid four" style="margin-bottom:18px">
                <div class="stat-tile"><div class="stat-value">${profile.matches || 0}</div><div class="stat-label">Matches</div></div>
                <div class="stat-tile"><div class="stat-value">${profile.headshots || 0}</div><div class="stat-label">Headshots</div></div>
                <div class="stat-tile"><div class="stat-value">${profile.bestStreak || 0}</div><div class="stat-label">Best streak</div></div>
                <div class="stat-tile"><div class="stat-value">${profile.level || 1}</div><div class="stat-label">Level</div></div>
            </div>

            <div class="row" style="align-items:flex-start;gap:16px">
                <div class="grow">
                    <div class="section-title">Leaderboard</div>
                    <div class="card pad-0">
                        <table>
                            <thead>
                                <tr>
                                    <th style="width:44px">#</th>
                                    <th>Player</th>
                                    <th class="right" data-sort="kills">Kills</th>
                                    <th class="right">Deaths</th>
                                    <th class="right" data-sort="kd">K/D</th>
                                    <th class="right" data-sort="wins">Wins</th>
                                    <th class="right" data-sort="xp">XP</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${board.length === 0
                                    ? '<tr><td colspan="7" style="color:var(--ink-3);text-align:center;padding:26px">Nobody has played yet.</td></tr>'
                                    : board.map((row, index) => `
                                    <tr>
                                        <td class="mono">${index + 1}</td>
                                        <td>${esc(row.name || row.citizenid)}</td>
                                        <td class="mono right">${row.kills || 0}</td>
                                        <td class="mono right">${row.deaths || 0}</td>
                                        <td class="mono right">${row.kd}</td>
                                        <td class="mono right">${row.wins || 0}</td>
                                        <td class="mono right">${row.xp || 0}</td>
                                    </tr>`).join('')}
                            </tbody>
                        </table>
                    </div>
                </div>

                <div style="width:340px;flex:0 0 340px">
                    <div class="section-title">Recent matches</div>
                    <div class="card pad-0">
                        ${history.length === 0
                            ? '<div class="empty" style="border:0">No matches recorded yet.</div>'
                            : `<div class="list">
                                ${history.map(row => `
                                    <div class="list-row">
                                        <div class="list-main">
                                            <div class="list-name" style="font-size:12.5px">${esc(row.mode)} — ${esc(row.map)}</div>
                                            <div class="list-sub">${esc(row.winner)} &middot; ${clock(row.duration)} &middot; ${(row.players || []).length} players</div>
                                        </div>
                                        ${row.pot ? `<span class="tag yellow">${money(row.pot)}</span>` : ''}
                                    </div>`).join('')}
                            </div>`}
                    </div>
                </div>
            </div>`;

        document.querySelectorAll('[data-scope]').forEach(el => {
            el.addEventListener('click', () => {
                STATS.scope = el.dataset.scope;
                renderStats();
            });
        });

        content.querySelectorAll('[data-sort]').forEach(el => {
            el.style.cursor = 'pointer';
            el.addEventListener('click', () => {
                STATS.sortBy = el.dataset.sort;
                renderStats();
            });
        });
    });
}
