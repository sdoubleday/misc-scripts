/*This mod works on the current database, and the logins only work for one login at a time
that was a hack to get around my lack of complete server permissions*/
/*For best results, use results to text.



from http://www.sqlserver-query.com/script-out-of-database-users-in-sql-server/

*/
DECLARE @ServerPrincipal sysname = '%' /*Only used for the creation of a user. Everything else just
scripts out all permissions.
We do this because getting Logins created is beyond this scope... I think.*/
DECLARE @DatabaseUserName [sysname] 
SET NOCOUNT ON
DECLARE
@errStatement [varchar](8000),
@msgStatement [varchar](8000),
@DatabaseUserID [smallint],
@ServerUserName [sysname],
@RoleName [varchar](8000),
@MEmberName [varchar](800),
@ObjectID [int],
@ObjectName [varchar](261)


/*Let's declare our cursors*/
DECLARE _users
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 

select [sys].[database_principals].[name] As FauxServerPrincipalName,
         [sys].[database_principals].[name]
from [sys].[database_principals]  
--INNER JOIN [master].[sys].[server_principals]
--on [sys].[database_principals].[name]=[master].[sys].[server_principals].[name]
where sys.database_principals.name like @ServerPrincipal 
--[master].[sys].[server_principals].[type] in ('U', 'G', 'S')

DECLARE _roles
CURSOR LOCAL FORWARD_ONLY READ_ONLY 
FOR
select [NAME] from [sys].[database_principals] where type='R' and is_fixed_role != 1 and name not like 'public'

DECLARE _role_members
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
SELECT a.name , b.name 
from sys.database_role_members d INNER JOIN sys.database_principals  a
                                on  d.role_principal_id=a.principal_id 
                                 INNER JOIN sys.database_principals  b
                                on d.member_principal_id=b.principal_id
                                where    b.name <> 'dbo'
                                order by 1,2





/*
Now, we will use them
*/

PRINT '/* CREATE USERS */'
OPEN _users FETCH NEXT FROM _users INTO @ServerUserNAme, @DatabaseUserName
WHILE @@FETCH_STATUS = 0
BEGIN

SET @msgStatement = 'CREATE USER ['        /*CREATE USER [SomeUser] FOR LOGIN [SomeLogin]*/
 + @DatabaseUserName + ']' + ' FOR LOGIN [' + @ServerUserName + ']'  
/*PRINT SD - I changed this to a select for aesthetic and usability reasons*/
SELECT @msgStatement
FETCH NEXT FROM _users INTO @ServerUserNAme, @DatabaseUserNAme
END

PRINT '/* CREATE DB ROLES*/'
OPEN _roles FETCH NEXT FROM _roles INTO @RoleName
WHILE @@FETCH_STATUS=0
BEGIN
SET @msgStatement ='if not exists(SELECT 1 from sys.database_principals where type=''R'' and name ='''
+@RoleName+''' ) '+ CHAR(13) +
'BEGIN '+ CHAR(13) +
'CREATE ROLE  ['+ @RoleName + ']'+CHAR(13) +
'END'
PRINT @msgStatement
FETCH NEXT FROM _roles INTO @RoleName
END

PRINT '/* ADD ROLE MEMBERS*/'

OPEN _role_members FETCH NEXT FROM _role_members INTO @RoleName, @membername
WHILE @@FETCH_STATUS = 0
BEGIN
SET @msgStatement = 'EXEC [sp_addrolemember] ' + '@rolename = [' + @RoleName + '], ' + '@membername = [' + @membername + ']'
PRINT @msgStatement
FETCH NEXT FROM _role_members INTO @RoleName, @membername
END

/* SCRIPT GRANTS for Database Privileges */
PRINT '/* SCRIPT GRANTS for Database Privileges*/'
SELECT a.state_desc + ' ' + a.permission_name + ' ' + '[' + b.name + ']' COLLATE LATIN1_General_CI_AS
FROM sys.database_permissions a inner join sys.database_principals b
ON a.grantee_principal_id = b.principal_id 
/*WHERE b.principal_id not in (0,1,2) and a.type in ('VW','VWDS') --modified 9/17/2012*/
WHERE b.principal_id not in (0,1,2) and a.type not in ('CO') and a.class = 0

/* SCRIPT GRANTS for Schema Privileges*/
PRINT '/* SCRIPT GRANTS for Schema Privileges*/'
SELECT a.state_desc + ' ' + a.permission_name + ' ' + 'ON SCHEMA::[' + b.name + '] to [' + c.name + ']' COLLATE LATIN1_General_CI_AS
FROM sys.database_permissions  a INNER JOIN sys.schemas b
ON  a.major_id = b.schema_id INNER JOIN sys.database_principals c ON a.grantee_principal_id = c.principal_id

/* SCRIPT GRANTS for Objects Level Privileges*/
PRINT '/* SCRIPT GRANTS for Object Privileges*/'
SELECT
state_desc + ' ' + permission_name + ' on ['+ sys.schemas.name + '].[' + sys.objects.name + '] to [' + sys.database_principals.name + ']' COLLATE LATIN1_General_CI_AS
from sys.database_permissions
join sys.objects on sys.database_permissions.major_id = 
sys.objects.object_id
join sys.schemas on sys.objects.schema_id = sys.schemas.schema_id
join sys.database_principals on sys.database_permissions.grantee_principal_id = 
sys.database_principals.principal_id
where sys.database_principals.name not in ( 'public', 'guest')

/*order by 1, 2, 3, 5 */

/*SD Addition
Script Database level GRANT IMPERSONATE*/
PRINT '/* SCRIPT GRANTS for Database-Level Impersonates*/'
SELECT pe.state_desc + ' ' + pe.permission_name + ' ON USER::[' + pr2.name  + '] TO [' + pr.name + ']' COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.database_permissions pe
    JOIN sys.database_principals pr
        ON pe.grantee_principal_id = pr.principal_Id
    JOIN sys.database_principals pr2
        ON pe.grantor_principal_id = pr2.principal_Id
WHERE pe.type = 'IM'  
/*SD Addition
Script Server level GRANT IMPERSONATE*/
PRINT '/* SCRIPT GRANTS for Server-Level Impersonates*/'
SELECT pe.state_desc + ' ' + pe.permission_name + ' ON LOGIN::[' + pr2.name  + '] TO [' + pr.name + ']' COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.server_permissions pe
    JOIN sys.server_principals pr
        ON pe.grantee_principal_id = pr.principal_Id
    JOIN sys.server_principals pr2
        ON pe.grantor_principal_id = pr2.principal_Id
WHERE pe.type = 'IM'  