USE [master]
GO
---For Always On CLusters only
SELECT AGC.name as 'AOGroupName'
       , DRS.replica_server_name as 'AOHost'
       , ADC.database_name as 'AODatabase'
       , DRS.role_desc AS 'Role'
       , CASE DRS.synchronization_state 
              WHEN 0 THEN 2 
              WHEN 1 THEN 0 
              WHEN 2 THEN 0
              WHEN 3 THEN 1
              WHEN 4 THEN 1
              END as 'AODatabaseSynchronizationState'
       , DRS.synchronization_health_desc
       , DRS.synchronization_state_desc
       , DRS.availability_mode_desc
       , DRS.failover_mode_desc
       , DRS.session_timeout
       , DRS.is_suspended
       , DRS.suspend_reason_desc
       , DRS.log_send_queue_size
       , DRS.log_send_rate
       , DRS.redo_queue_size
       , DRS.redo_rate
       , DRS.filestream_send_rate
       , DRS.last_commit_time
       , DRS.AutoPageRepairCount
       , ALIST.dns_name
       , ALIST.port
       , ALIST.ip_configuration_string_from_cluster
       INTO #AGHealth
       FROM [master].[sys].[availability_groups_cluster] as AGC
       LEFT JOIN [master].[sys].[availability_databases_cluster] as ADC
              ON AGC.group_id=ADC.group_id
       LEFT JOIN [master].[sys].[availability_group_listeners] AS ALIST
              ON ALIST.group_id = AGC.group_id
       LEFT JOIN (   SELECT DRStates.group_id
                           , DRStates.group_database_id
                           , DRStates.synchronization_state
                           , ISNULL(DRStates.synchronization_state_desc, ' ') as synchronization_state_desc
                           , is_suspended
                           , ISNULL(DRStates.suspend_reason_desc, ' ') as suspend_reason_desc
                           , ISNULL(DRStates.log_send_queue_size,0) as log_send_queue_size
                           , ISNULL(DRStates.log_send_rate,0) as log_send_rate
                           , ISNULL(DRStates.redo_queue_size,0) as redo_queue_size
                           , ISNULL(DRStates.redo_rate,0) as redo_rate
                           , ISNULL(DRStates.filestream_send_rate,0) as filestream_send_rate
                           , ISNULL(APRC.AutoPageRepairCount,0) AS AutoPageRepairCount
                           , AR.replica_server_name
                           , ARS.role_desc
                           , DRStates.last_commit_time
                           , ARS.synchronization_health_desc
                           , AR.availability_mode_desc
                           , AR.failover_mode_desc
                           , AR.session_timeout
                     FROM [master].[sys].[dm_hadr_database_replica_states] as DRStates
                     INNER JOIN [master].[sys].[availability_replicas] AS AR 
                           ON AR.replica_id = DRStates.replica_id
                     INNER JOIN [master].[sys].[dm_hadr_availability_replica_states] as ARS
                           ON ARS.replica_id = DRStates.replica_id
                     LEFT JOIN (SELECT database_id
                                                , COUNT(database_id) AS 'AutoPageRepairCount' 
                                         FROM [master].[sys].[dm_hadr_auto_page_repair] as APR 
                                         WHERE APR.modification_time >= DATEADD(dd,-10,GETDATE()) 
                                         GROUP BY APR.database_id
                                         ) AS APRC
                           ON APRC.database_id = DRStates.database_id
                     ) as DRS
              ON ADC.group_id = DRS.group_id 
                     AND ADC.group_database_id = DRS.group_database_id
              WHERE AGC.group_id IN (SELECT group_id
                                                FROM [master].[sys].[dm_hadr_availability_replica_states] as PARS
                                                WHERE PARS.is_local = 1
                                                       AND PARS.role = 1
                                                )

SELECT AOGroupName
       , Role
       , AOHost
       , synchronization_health_desc
       , synchronization_state_desc
       , availability_mode_desc
       , suspend_reason_desc
       , SUM(log_send_queue_size) AS [log_send_queue_size]
       , AVG(log_send_rate) AS [log_send_rate\KBs]
       , SUM(redo_queue_size) AS [redo_queue_size]
       , AVG(redo_rate) AS [redo_rate\KBs]
       , MIN(last_commit_time) AS [last_commit_time]
FROM #AGHealth
GROUP BY AOGroupName
       , AOHost
       , Role
       , synchronization_health_desc
       , synchronization_state_desc
       , availability_mode_desc
       , suspend_reason_desc
ORDER BY AOGroupName
       , Role
       , AOHost
       , synchronization_health_desc
       , synchronization_state_desc
       , availability_mode_desc
       , suspend_reason_desc


DROP TABLE #AGHealth
GO
