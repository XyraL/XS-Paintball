CREATE TABLE IF NOT EXISTS `xs_paintball_maps` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `preset` VARCHAR(64) DEFAULT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `data` LONGTEXT NOT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `preset` (`preset`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_stats` (
    `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `kills` INT NOT NULL DEFAULT 0,
    `deaths` INT NOT NULL DEFAULT 0,
    `assists` INT NOT NULL DEFAULT 0,
    `headshots` INT NOT NULL DEFAULT 0,
    `captures` INT NOT NULL DEFAULT 0,
    `wins` INT NOT NULL DEFAULT 0,
    `losses` INT NOT NULL DEFAULT 0,
    `matches` INT NOT NULL DEFAULT 0,
    `best_streak` INT NOT NULL DEFAULT 0,
    `xp` INT NOT NULL DEFAULT 0,
    `level` INT NOT NULL DEFAULT 1,
    `tint` INT NOT NULL DEFAULT 0,
    `kit` VARCHAR(32) DEFAULT NULL,
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `kills` (`kills`),
    KEY `xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_weekly` (
    `citizenid` VARCHAR(64) NOT NULL,
    `week` VARCHAR(10) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `kills` INT NOT NULL DEFAULT 0,
    `deaths` INT NOT NULL DEFAULT 0,
    `wins` INT NOT NULL DEFAULT 0,
    `xp` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `week`),
    KEY `week_kills` (`week`, `kills`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_history` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `map` VARCHAR(64) DEFAULT NULL,
    `mode` VARCHAR(24) DEFAULT NULL,
    `winner` VARCHAR(24) DEFAULT NULL,
    `duration` INT NOT NULL DEFAULT 0,
    `pot` INT NOT NULL DEFAULT 0,
    `players` LONGTEXT DEFAULT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_loadouts` (
    `citizenid` VARCHAR(64) NOT NULL,
    `slot` TINYINT NOT NULL DEFAULT 1,
    `label` VARCHAR(32) DEFAULT NULL,
    `data` TEXT NOT NULL,
    PRIMARY KEY (`citizenid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_outfits` (
    `citizenid` VARCHAR(64) NOT NULL,
    `team` VARCHAR(12) NOT NULL,
    `data` LONGTEXT NOT NULL,
    PRIMARY KEY (`citizenid`, `team`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_settings` (
    `k` VARCHAR(48) NOT NULL,
    `v` TEXT DEFAULT NULL,
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_paintball_stashes` (
    `citizenid` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
