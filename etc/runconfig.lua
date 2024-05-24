return {
    -- 集群
    cluster = {
        main = "127.0.0.1:7771"
    },
    -- 唯一服配置
    unique = {
        login_mgr = {node = "main"},
        db_mysql = {
            node = "main",
            config = {
                host = "127.0.0.1",
                port = 3306,
                database = "game",
                user = "root",
                password = "hr@123-zzh",
                charset = "utf8mb4",
                -- MEDIUMBLOB： 最大大小为 16,777,215 字节（16 MB）
                max_packet_size = 1024 * 1024 * 16
            }
        },
        db_redis = {}
    },
    debug_console = {
        main = {port = 8001}
    },
    -- gateway应该最后启动，启动时应该顺序启动保证启动完才启动下一个
    main = {
        [1] = {
            name = "srv_game",
            list = {
                [1] = {},
                [2] = {},
                [3] = {}
            }
        },
        [2] = {
            name = "login",
            list = {
                [1] = {},
                [2] = {}
            }
        },
        [3] = {
            name = "gateway",
            list = {
                [1] = {port = 8501},
                [2] = {port = 8503}
            }
        }
    }
}
