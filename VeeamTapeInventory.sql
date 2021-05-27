USE veeamBAR;


/*
SELECT
  *
FROM
  INFORMATION_SCHEMA.TABLES;
*/

--SELECT COUNT(*) as Cuenta FROM [Tape.directories];
/*SELECT
 *
FROM dbo.[Tape.directories];*/




    WITH PathInfo AS
    (
     SELECT  [Id]
    ,Parent_Id
    ,Name
    ,FolderPath = CONVERT(NVARCHAR(800), name)
       FROM dbo.[Tape.directories]
      WHERE Parent_Id IS NULL
      UNION ALL
     SELECT  TempTD.Id
    ,TempTD.Parent_Id
    ,TempTD.name
    ,FolderPath = CONVERT(NVARCHAR(800), cte.FolderPath+'\'+TempTD.name)
       FROM [dbo].[Tape.directories] TempTD
       JOIN PathInfo cte ON cte.Id = TempTD.Parent_Id
    )

SELECT
TTM_Barcode AS BarcodeID,
--TH_Name AS Backup_Server,
Folder_Path,
TF_Name AS File_Name,
--TFP_Incompletion AS FileSegmentNumber, 
File_Size_GB,
--Tape_Capacity_GB,
--Tape_Remaining_GB,
--TTM_Protected AS IsTapeProtected,
CASE WHEN 
Tape_Physical_Location IS NULL THEN 'Offline'
ELSE Tape_Physical_Location
END AS Tape_Physical_Location,
TB_Name AS Tape_Backup_Job,
TBS_Name AS Tape_Backup_Set,
TBS_ExpirationDate AS Tape_Backup_Set_Expiration,
TTM_LastWriteTime AS Last_Write_Time,
--TTM_Description AS Tape_Description,
TMP_Name AS Tape_Media_Pool
--TMP_Description AS Tape_Media_Pool_Description

FROM
(SELECT TFV.file_id AS TFV_FileID,
TFV.backup_set_id AS TFV_BackupSetID,
TFV.id AS TFV_ID,
CAST(TFV.Size / 1073741824.0E AS DECIMAL(10, 2)) AS File_Size_GB,
TF.directory_id AS TF_DirectoryID,
TF.name AS TF_Name,
TFP.media_sequence_number AS TFP_MediaSequenceNumber,
TFP.id AS TFP_ID,
TFP.file_version_id AS TFP_FileVersionID,
TFP.incompletion AS TFP_Incompletion,
TH.name AS TH_Name,
PathInfo.folderpath AS Folder_Path
     FROM [Tape.file_versions] AS TFV
LEFT JOIN [dbo].[Tape.file_parts] TFP  
ON TFV.id = TFP.file_version_id
LEFT JOIN [Tape.files] TF 
ON TFV.file_id = TF.id
LEFT JOIN [Tape.directories] TD 
ON TF.directory_id = TD.id
LEFT JOIN [Tape.hosts] TH 
ON TD.host_id = TH.id
INNER JOIN PathInfo
ON PathInfo.id = TD.id
) AS FileParts
  RIGHT JOIN 
(SELECT TTM.id AS TTM_ID,
TTM.barcode as TTM_Barcode,
TTM.media_sequence_number AS TTM_MediaSequenceNumber,
TTM.location_address AS TTM_LocationAddress,
TTM.Last_Write_Time AS TTM_LastWriteTime,
TTM.Description AS TTM_Description,
CASE TTM.Protected
WHEN '0' THEN 'No'
WHEN '1' THEN 'Yes'
ELSE 'Other'
END AS TTM_Protected,
TTMBS.tape_medium_id AS TTMBS_TapeMediumID,
TTMBS.backup_set_id AS TTMBS_BackupSetID,
TBS.id AS TBS_ID,
TBS.name AS TBS_Name,
TBS.backup_id AS TBS_BackupID,
TBS.expiration_date AS TBS_ExpirationDate,
TB.name AS TB_Name,
TMV.description AS TMV_Description,
TMV.name AS TMV_Name,
CAST(TTM.Capacity / 1073741824.0E AS DECIMAL(10, 2)) AS Tape_Capacity_GB,
CAST(TTM.Remaining / 1073741824.0E AS DECIMAL(10, 2)) AS Tape_Remaining_GB,
TL.Name AS TL_Name,
TL.id AS TL_ID,
TL.tape_server_id AS TL_TapeServerID,
TTM.Location_type AS TTM_LocationType,
CASE TTM.Location_Type
WHEN '0' THEN TL.Name + ' - Tape Drive'
WHEN '1' THEN TL.Name + ' - Slot ' + CAST((TTM.Location_Address + 1) AS NVARCHAR(255))
WHEN '2' THEN 'Tape Vault - ' + TMV.Name
ELSE 'Other'
END AS Tape_Physical_Location,
TMP.name AS TMP_Name,
TMP.Description AS TMP_Description  
FROM [Tape.tape_mediums] AS TTM
LEFT JOIN [dbo].[Tape.tape_medium_backup_sets] TTMBS  
ON TTM.id = TTMBS.tape_medium_id
LEFT JOIN  [dbo].[Tape.backup_sets] TBS 
ON TTMBS.backup_set_id = TBS.id
LEFT JOIN [Tape.backups] TB 
ON TBS.backup_id = TB.id
LEFT JOIN [Tape.media_in_vaults] TMIV
ON TTM.id = TMIV.media_id
LEFT JOIN [Tape.media_vaults] TMV
ON TMIV.vault_id = TMV.id
LEFT JOIN [Tape.libraries] TL
ON TTM.location_library_id = TL.id
INNER JOIN [Tape.media_pools] TMP
ON media_pool_id = TMP.id 
) AS BackupSets
ON BackupSets.TBS_ID = FileParts.TFV_BackupSetID
AND BackupSets.TTM_MediaSequenceNumber = FileParts.TFP_MediaSequenceNumber

WHERE TMP_Name NOT LIKE '%Unrecognized%' and TTM_LastWriteTime >= GETDATE() - (SELECT DAY(EOMONTH(GETDATE())))

ORDER BY Last_Write_Time

