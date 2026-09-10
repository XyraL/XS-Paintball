const HUD = {
    root: null,
    active: false,
    config: {},
    roster: [],
    scores: {},
    objectives: {},
    killfeed: [],
    spectating: false,
};

function hudEl(id) {
    return document.getElementById(id);
}

function hudStart(config) {
    HUD.config = config || {};
    HUD.active = true;
    HUD.roster = [];
    HUD.scores = {};
    HUD.objectives = {};
    HUD.killfeed = [];
    HUD.spectating = config && config.spectator === true;

    hudEl('hud').classList.remove('hidden');
    hudEl('hud-mode').textContent = config.modeLabel || '';
    hudEl('hud-time').textContent = clock(config.timeLeft);
    hudEl('hud-killfeed').innerHTML = '';
    hudEl('hud-announce').innerHTML = '';
    hudEl('hud-result').classList.add('hidden');
    hudEl('hud-scoreboard').classList.add('hidden');
    hudEl('hud-respawn').classList.add('hidden');
    hudEl('hud-bounds').classList.add('hidden');
    hudEl('hud-goggles').classList.toggle('hidden', HUD.spectating || config.goggles === false);
    hudEl('hud-spectate').classList.toggle('hidden', !HUD.spectating);
    hudEl('hud-bottom').classList.toggle('hidden', HUD.spectating);

    hudPaint({ current: config.paint || 100, max: config.paintMax || 100 });
    hudRenderRounds();
    hudRenderScores();
    hudRenderObjectives();
    hudRenderBadges();
}

function hudStop() {
    HUD.active = false;
    HUD.spectating = false;

    if (HUD.voteTimer) { clearInterval(HUD.voteTimer); HUD.voteTimer = null; }
    HUD.vote = null;

    const root = hudEl('hud');
    root.classList.add('hidden');

    hudEl('hud-scoreboard').classList.add('hidden');
    hudEl('hud-result').classList.add('hidden');
    hudEl('hud-respawn').classList.add('hidden');
    hudEl('hud-bounds').classList.add('hidden');
    hudEl('hud-spectate').classList.add('hidden');
    hudEl('hud-killfeed').innerHTML = '';
    hudEl('hud-badges').innerHTML = '';
    hudEl('hud-vote').classList.add('hidden');
    hudEl('hud-loadout').classList.add('hidden');
    hudEl('hud-team').classList.add('hidden');
    hudEl('hud-goggles').classList.add('hidden');
}

function hudRenderScores() {
    const host = hudEl('hud-scores');
    const teams = HUD.config.teams || [];

    if (teams.length > 0) {
        host.innerHTML = teams.map(team => `
            <div class="hud-score ${teamClass(team)} ${team === HUD.config.team ? 'self' : ''}">
                <span class="label">${esc((HUD.config.teamData?.[team]?.label) || team)}</span>
                <span class="value">${Number(HUD.scores[team] || 0)}</span>
            </div>`).join('');
        return;
    }

    const me = HUD.roster.find(r => r.self);
    const leader = HUD.roster[0];

    host.innerHTML = `
        <div class="hud-score self">
            <span class="label">${esc(HUD.config.scoreLabel || 'Score')}</span>
            <span class="value">${Number((me && me.score) || 0)}</span>
        </div>
        ${leader ? `<div class="hud-score"><span class="label">Lead</span><span class="value">${Number(leader.score || 0)}</span></div>` : ''}`;
}

function hudRenderObjectives() {
    const host = hudEl('hud-objective');
    const mode = HUD.config.mode;

    if (mode === 'ctf' && HUD.objectives.flags) {
        host.innerHTML = Object.keys(HUD.objectives.flags).map(team => {
            const flag = HUD.objectives.flags[team];
            const label = flag.state === 'home' ? 'Home' : flag.state === 'carried' ? 'Taken' : 'Dropped';
            return `<div class="hud-obj"><span class="pill ${teamClass(team)}">F</span>${esc(label)}</div>`;
        }).join('');
        return;
    }

    if (mode === 'domination' && HUD.objectives.points) {
        host.innerHTML = Object.keys(HUD.objectives.points).sort().map(id => {
            const point = HUD.objectives.points[id];
            const owner = point.owner ? teamClass(point.owner) : '';
            const pct = point.capturing ? Math.round((point.progress || 0) * 100) : null;
            return `<div class="hud-obj"><span class="pill ${owner}">${esc(point.id)}</span>${pct !== null ? `${pct}%` : (point.owner ? 'Held' : 'Open')}</div>`;
        }).join('');
        return;
    }

    if (mode === 'confirmed' && HUD.objectives.tags) {
        const count = Object.keys(HUD.objectives.tags).length;
        host.innerHTML = `<div class="hud-obj"><span class="pill">T</span>${count} tag${count === 1 ? '' : 's'} on the floor</div>`;
        return;
    }

    if (mode === 'gungame' && HUD.config.tier) {
        host.innerHTML = `<div class="hud-obj"><span class="pill">${HUD.config.tier}</span>${esc(HUD.config.tierLabel || '')}</div>`;
        return;
    }

    host.innerHTML = '';
}

function hudRenderBadges() {
    const host = hudEl('hud-badges');
    const badges = [];

    if (HUD.protection > 0) badges.push({ text: `Spawn shield ${HUD.protection}s`, cls: 'accent' });
    if (HUD.streak) badges.push({ text: `${HUD.streak.label} ${HUD.streak.remaining || ''}`.trim(), cls: 'green' });
    if (HUD.tier) badges.push({ text: `Tier ${HUD.tier.tier} / ${HUD.tier.total} — ${HUD.tier.label || ''}`, cls: 'amber' });
    if (HUD.config.wager) badges.push({ text: `Wager ${money(HUD.config.wager)}`, cls: '' });

    host.innerHTML = badges.map(b => `<div class="hud-badge ${b.cls}">${esc(b.text)}</div>`).join('');
}


function hudRenderRounds() {
    const host = hudEl('hud-rounds');
    const total = HUD.config.rounds || 1;

    if (total <= 1) { host.classList.add('hidden'); return; }

    const wins = HUD.config.roundWins || {};
    const teams = HUD.config.teams || [];
    const order = [];

    // One pip per round, filled in the colour of whoever took it.
    teams.forEach(team => {
        for (let i = 0; i < (wins[team] || 0); i += 1) order.push(team);
    });

    if (teams.length === 0) {
        const taken = Object.values(wins).reduce((sum, n) => sum + n, 0);
        for (let i = 0; i < taken; i += 1) order.push('done');
    }

    let html = '';
    for (let i = 0; i < total; i += 1) {
        const team = order[i];
        const now = i === (HUD.config.round || 1) - 1 && !team;
        html += `<span class="round-pip ${team && team !== 'done' ? teamClass(team) : ''} ${team === 'done' ? 'now' : ''} ${now ? 'now' : ''}"></span>`;
    }

    host.innerHTML = html;
    host.classList.remove('hidden');
}

function hudRoundScreen(data) {
    const host = hudEl('hud-result');
    if (!data) { host.classList.add('hidden'); return; }

    const teams = data.teams || [];
    const wins = data.roundWins || {};

    let title = 'Round drawn';
    let tone = 'draw';

    if (data.winnerTeam) {
        title = `${esc((HUD.config.teamData?.[data.winnerTeam]?.label) || data.winnerTeam)} take it`;
        tone = data.winnerTeam === HUD.config.team ? 'win' : 'loss';
    } else if (data.winnerName) {
        const me = HUD.roster.find(r => r.self);
        title = `${esc(data.winnerName)} takes it`;
        tone = me && me.name === data.winnerName ? 'win' : 'loss';
    }

    host.innerHTML = `
        <div class="result-card">
            <div class="result-kicker">Round ${data.round} of ${data.rounds}</div>
            <div class="result-title ${tone}">${title}</div>
            <div class="result-sub">Next round in ${data.breakSeconds}s</div>
            ${teams.length ? `<div class="round-wins">
                ${teams.map(team => `
                    <div class="side ${teamClass(team)}">
                        <div class="v">${wins[team] || 0}</div>
                        <div class="l">${esc((HUD.config.teamData?.[team]?.label) || team)}</div>
                    </div>`).join('')}
            </div>` : ''}
        </div>`;

    host.classList.remove('hidden');
}

function hudVote(data) {
    const host = hudEl('hud-vote');

    if (!data) {
        host.classList.add('hidden');
        HUD.vote = null;
        if (HUD.voteTimer) { clearInterval(HUD.voteTimer); HUD.voteTimer = null; }
        return;
    }

    if (HUD.voteTimer) clearInterval(HUD.voteTimer);

    HUD.vote = { options: data.options, tally: {}, choice: null, left: data.seconds };
    hudVoteRender();
    host.classList.remove('hidden');

    HUD.voteTimer = setInterval(() => {
        if (!HUD.vote) { clearInterval(HUD.voteTimer); HUD.voteTimer = null; return; }
        if (HUD.vote.left <= 0) return;

        HUD.vote.left -= 1;
        hudVoteRender();
    }, 1000);
}

function hudVoteRender() {
    const host = hudEl('hud-vote');
    const state = HUD.vote;
    if (!state) return;

    const total = Object.values(state.tally).reduce((sum, n) => sum + n, 0) || 1;

    host.innerHTML = `
        <div class="vote-head"><span>Next map</span><span class="vote-clock">${state.left}s</span></div>
        ${state.options.map((option, index) => {
            const count = state.tally[index + 1] || 0;
            const pct = Math.round((count / total) * 100);
            return `
                <div class="vote-row ${state.choice === index + 1 ? 'mine' : ''}">
                    <span class="key">${index + 1}</span>
                    <span>${esc(option.name)}</span>
                    <span class="count">${count}</span>
                </div>
                <div class="bar" style="width:${pct}%"></div>`;
        }).join('')}
        <div class="vote-foot">Press 1 - ${state.options.length} to vote</div>`;
}

function hudTeam(data) {
    const host = hudEl('hud-team');

    if (!data || !data.rows || data.rows.length === 0) { host.classList.add('hidden'); return; }

    host.innerHTML = `
        <div class="team-head ${teamClass(data.team)}">${esc((HUD.config.teamData?.[data.team]?.label) || data.team)}</div>
        ${data.rows.map(row => `
            <div class="team-row ${row.alive ? '' : 'out'} ${row.you ? 'you' : ''}">
                <span class="team-dot ${row.talking ? 'talking' : ''}"></span>
                <span class="team-name">${esc(row.name)}</span>
                <span class="team-kills">${row.kills}</span>
            </div>`).join('')}`;

    host.classList.remove('hidden');
}

function hudLoadout(slots) {
    const host = hudEl('hud-loadout');

    if (!slots || slots.length === 0) { host.classList.add('hidden'); return; }

    host.innerHTML = slots.map(slot => `
        <div class="lo-slot ${slot.active ? 'active' : ''} ${slot.missing ? 'missing' : ''}">
            <span class="lo-key">${esc(slot.key)}</span>
            <span class="lo-body">
                <span class="lo-name">${esc(slot.label)}</span>
                <span class="lo-sub">${slot.missing ? 'gone' : (slot.ammo !== undefined && slot.ammo !== null ? `${slot.ammo} paint` : esc(slot.slot))}</span>
            </span>
        </div>`).join('');

    host.classList.remove('hidden');
}

function hudQueue(state) {
    const host = hudEl('hud-queue');

    if (!state) { host.classList.add('hidden'); return; }

    host.innerHTML = `
        <div class="queue-title">In the queue</div>
        <div class="queue-count">${state.size} of ${state.needed} needed</div>`;

    host.classList.remove('hidden');
}

function hudPaint(data) {
    const max = Math.max(1, data.max || 100);
    const current = Math.max(0, Math.min(max, data.current || 0));
    const pct = (current / max) * 100;

    const fill = document.querySelector('.paint-fill');
    fill.style.width = `${pct}%`;
    fill.classList.toggle('low', pct <= 30);

    hudEl('hud-paint-value').textContent = Math.round(current);
}

function hudSplat() {
    const el = hudEl('hud-splat');
    el.classList.add('on');
    setTimeout(() => el.classList.remove('on'), 420);
}

function hudHitMarker() {
    const el = hudEl('hud-hitmarker');
    el.classList.remove('on');
    void el.offsetWidth;
    el.classList.add('on');
}

function hudKillfeed(entry) {
    HUD.killfeed.push(entry);
    if (HUD.killfeed.length > 6) HUD.killfeed.shift();

    hudKillfeedRender();

    setTimeout(() => {
        const index = HUD.killfeed.indexOf(entry);
        if (index >= 0) {
            HUD.killfeed.splice(index, 1);
            hudKillfeedRender();
        }
    }, 7000);
}

function hudKillfeedRender() {
    const host = hudEl('hud-killfeed');
    host.innerHTML = HUD.killfeed.map(row => `
        <div class="kf-row">
            <span class="name ${teamClass(row.killerTeam)}">${esc(row.killer || 'The arena')}</span>
            ${row.headshot ? '<span class="kf-head">HS</span>' : ''}
            <span class="kf-weapon">${esc(row.weapon || 'eliminated')}</span>
            <span class="name ${teamClass(row.victimTeam)}">${esc(row.victim)}</span>
        </div>`).join('');
}

function hudAnnounce(payload) {
    const host = hudEl('hud-announce');

    const el = document.createElement('div');
    el.className = `announce ${payload.tone || 'inform'}`;
    el.textContent = payload.text;
    host.appendChild(el);

    setTimeout(() => {
        el.style.transition = 'opacity .25s ease';
        el.style.opacity = '0';
        setTimeout(() => el.remove(), 250);
    }, 2600);
}

function hudScoreboard(show) {
    const host = hudEl('hud-scoreboard');

    if (!show) {
        host.classList.add('hidden');
        return;
    }

    const teams = HUD.config.teams || [];
    const groups = [];

    if (teams.length > 0) {
        teams.forEach(team => {
            groups.push({
                team,
                label: (HUD.config.teamData?.[team]?.label) || team,
                score: HUD.scores[team] || 0,
                rows: HUD.roster.filter(r => r.team === team),
            });
        });

        const loose = HUD.roster.filter(r => !teams.includes(r.team));
        if (loose.length) groups.push({ team: null, label: 'Spectators', score: '', rows: loose });
    } else {
        groups.push({ team: null, label: HUD.config.modeLabel || 'Players', score: '', rows: HUD.roster });
    }

    const header = `
        <div class="sb-row head">
            <div>#</div><div>Player</div>
            <div class="stat">Score</div><div class="stat">K</div><div class="stat">D</div>
            <div class="stat">A</div><div class="stat">Ping</div>
        </div>`;

    host.innerHTML = `
        <div class="sb-panel">
            <div class="sb-head">
                <div>
                    <div class="sb-title">${esc(HUD.config.modeLabel || 'Match')}</div>
                    <div class="sb-sub">${esc(HUD.config.map || '')}</div>
                </div>
                <div style="text-align:right">
                    <div class="sb-title">${clock(HUD.timeLeft)}</div>
                    <div class="sb-sub">${esc(HUD.config.scoreLabel || 'Score')} to ${HUD.config.scoreLimit || '-'}</div>
                </div>
            </div>
            <div class="sb-body">
                ${groups.map(group => `
                    <div class="sb-teamhead ${teamClass(group.team)}">
                        <span>${esc(group.label)}</span>
                        <span>${group.score === '' ? '' : group.score}</span>
                    </div>
                    ${header}
                    ${group.rows.length === 0
                        ? '<div class="sb-row"><div></div><div style="color:var(--ink-3)">Nobody yet</div></div>'
                        : group.rows.map((row, index) => `
                        <div class="sb-row ${row.self ? 'self' : ''} ${row.alive ? '' : 'dead'}">
                            <div class="num">${index + 1}</div>
                            <div>${esc(row.name)}${row.host ? ' <span class="tag muted">host</span>' : ''}</div>
                            <div class="stat">${row.score || 0}</div>
                            <div class="stat">${row.kills || 0}</div>
                            <div class="stat">${row.deaths || 0}</div>
                            <div class="stat">${row.assists || 0}</div>
                            <div class="stat">${row.ping || 0}</div>
                        </div>`).join('')}
                `).join('')}
            </div>
        </div>`;

    host.classList.remove('hidden');
}

function hudResult(result) {
    const host = hudEl('hud-result');
    if (!result) { host.classList.add('hidden'); return; }

    const me = HUD.roster.find(r => r.self);
    let outcome = 'draw';
    let title = 'Draw';

    if (result.winnerTeam) {
        outcome = result.winnerTeam === HUD.config.team ? 'win' : 'loss';
        title = `${(HUD.config.teamData?.[result.winnerTeam]?.label) || result.winnerTeam} wins`;
    } else if (result.winnerName) {
        outcome = me && me.name === result.winnerName ? 'win' : 'loss';
        title = `${result.winnerName} wins`;
    }

    host.innerHTML = `
        <div class="result-card">
            <div class="result-kicker">${esc(HUD.config.modeLabel || '')} &middot; ${esc(HUD.config.map || '')}</div>
            <div class="result-title ${outcome}">${esc(title)}</div>
            <div class="result-sub">${result.pot ? `Pot ${money(result.pot)} &middot; ${money(result.share)} each` : 'No wager on this one'}</div>
            <div class="result-stats">
                <div class="result-stat"><div class="v">${(me && me.kills) || 0}</div><div class="l">Kills</div></div>
                <div class="result-stat"><div class="v">${(me && me.deaths) || 0}</div><div class="l">Deaths</div></div>
                <div class="result-stat"><div class="v">${ratio((me && me.kills) || 0, (me && me.deaths) || 0)}</div><div class="l">K/D</div></div>
                <div class="result-stat"><div class="v">${clock(result.duration)}</div><div class="l">Length</div></div>
            </div>
        </div>`;

    host.classList.remove('hidden');
}

function hudHandle(action, data) {
    switch (action) {
        case 'start': hudStart(data); break;
        case 'stop': hudStop(); break;

        case 'update':
            HUD.scores = data.scores || HUD.scores;
            HUD.roster = (data.roster || []).map(r => ({ ...r, self: r.source === HUD.selfSource }));
            HUD.timeLeft = data.timeLeft;
            hudEl('hud-time').textContent = clock(data.timeLeft);
            hudRenderScores();
            if (!hudEl('hud-scoreboard').classList.contains('hidden')) hudScoreboard(true);
            break;

        case 'self': HUD.selfSource = data; break;
        case 'time': hudEl('hud-time').textContent = clock(data); HUD.timeLeft = data; break;
        case 'paint': hudPaint(data); break;
        case 'splat': hudSplat(); break;
        case 'hitmarker': hudHitMarker(); break;
        case 'killfeed': hudKillfeed(data); break;
        case 'announce': hudAnnounce(data); break;
        case 'objectives': HUD.objectives = data || {}; hudRenderObjectives(); break;

        case 'state':
            if (data.state === 'alive') {
                hudEl('hud-respawn').classList.add('hidden');
                hudEl('hud-bottom').classList.remove('hidden');
            } else if (data.state === 'dead') {
                hudEl('hud-respawn').classList.remove('hidden');
                hudEl('hud-respawn').querySelector('.respawn-label').textContent = 'Eliminated';
                hudEl('hud-respawn').querySelector('.respawn-hint').textContent = 'Respawning';
            } else if (data.state === 'eliminated') {
                hudEl('hud-respawn').classList.remove('hidden');
                hudEl('hud-respawn').querySelector('.respawn-label').textContent = 'Out of the match';
                hudEl('hud-respawn').querySelector('.respawn-count').textContent = '';
                hudEl('hud-respawn').querySelector('.respawn-hint').textContent = 'Spectating';
            }
            break;

        case 'respawn':
            if (data > 0) {
                hudEl('hud-respawn').classList.remove('hidden');
                hudEl('hud-respawn').querySelector('.respawn-count').textContent = data;
            } else {
                hudEl('hud-respawn').classList.add('hidden');
            }
            break;

        case 'bounds':
            if (data === null || data === undefined) {
                hudEl('hud-bounds').classList.add('hidden');
            } else {
                hudEl('hud-bounds').classList.remove('hidden');
                hudEl('hud-bounds').querySelector('.bounds-count').textContent = data;
            }
            break;

        case 'protection': HUD.protection = data || 0; hudRenderBadges(); break;
        case 'streak': HUD.streak = data || null; hudRenderBadges(); break;

        case 'tier':
            HUD.tier = data || null;
            HUD.config.tier = data && data.tier;
            HUD.config.tierLabel = data && data.label;
            hudRenderBadges();
            hudRenderObjectives();
            break;

        case 'rounds':
            HUD.config.round = data.round;
            HUD.config.rounds = data.rounds;
            HUD.config.roundWins = data.roundWins;
            hudRenderRounds();
            break;

        case 'round': hudRoundScreen(data); break;
        case 'vote': hudVote(data || null); break;

        case 'voteTally':
            if (HUD.vote) { HUD.vote.tally = data || {}; hudVoteRender(); }
            break;

        case 'voteChoice':
            if (HUD.vote) { HUD.vote.choice = data; hudVoteRender(); }
            break;

        case 'voteResult':
            if (HUD.vote) {
                HUD.vote.left = 0;
                hudEl('hud-vote').innerHTML =
                    `<div class="vote-head"><span>Next map</span></div>
                     <div class="vote-row mine"><span>${esc(data.name)}</span><span class="count">${data.votes}</span></div>`;
            }
            break;

        case 'queue': hudQueue(data || null); break;
        case 'loadout': hudLoadout(data || null); break;
        case 'team': hudTeam(data || null); break;

        case 'scoreboard': hudScoreboard(data === true); break;
        case 'result': hudResult(data); break;
        case 'spectating': hudEl('hud-spectate').classList.toggle('hidden', data !== true); break;

        case 'spectateTarget': {
            const el = hudEl('hud-spectate').querySelector('.spectate-name');
            el.textContent = data ? data.name : 'Free camera';
            el.className = `spectate-name ${data ? teamClass(data.team) : ''}`;
            break;
        }

        case 'lobby': HUD.lobby = data || null; break;
    }
}
