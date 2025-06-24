const { Client } = require('pg');

async function checkTechbPPPermissions() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb_pp',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  console.log('========================================');
  console.log('  techb_pp 계정 권한 확인');
  console.log('========================================\n');

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공!\n');

    // 1. 현재 사용자 정보
    const userInfo = await client.query(`
      SELECT 
        current_user,
        current_database(),
        version()
    `);
    console.log('1. 사용자 정보:');
    console.log(`   - 사용자: ${userInfo.rows[0].current_user}`);
    console.log(`   - 데이터베이스: ${userInfo.rows[0].current_database}`);
    console.log(`   - PostgreSQL 버전: ${userInfo.rows[0].version.split(',')[0]}\n`);

    // 2. 사용자 역할 및 속성
    const userRoles = await client.query(`
      SELECT 
        rolname,
        rolsuper,
        rolinherit,
        rolcreaterole,
        rolcreatedb,
        rolcanlogin,
        rolreplication,
        rolbypassrls
      FROM pg_roles
      WHERE rolname = current_user
    `);
    console.log('2. 사용자 역할 속성:');
    const role = userRoles.rows[0];
    console.log(`   - Super User: ${role.rolsuper}`);
    console.log(`   - Create Role: ${role.rolcreaterole}`);
    console.log(`   - Create DB: ${role.rolcreatedb}`);
    console.log(`   - Can Login: ${role.rolcanlogin}`);
    console.log(`   - Replication: ${role.rolreplication}`);
    console.log(`   - Bypass RLS: ${role.rolbypassrls}\n`);

    // 3. 데이터베이스 권한
    const dbPrivs = await client.query(`
      SELECT 
        has_database_privilege(current_user, current_database(), 'CREATE') as can_create,
        has_database_privilege(current_user, current_database(), 'CONNECT') as can_connect,
        has_database_privilege(current_user, current_database(), 'TEMP') as can_temp
    `);
    console.log('3. 데이터베이스 권한:');
    const dbPriv = dbPrivs.rows[0];
    console.log(`   - CREATE: ${dbPriv.can_create}`);
    console.log(`   - CONNECT: ${dbPriv.can_connect}`);
    console.log(`   - TEMP: ${dbPriv.can_temp}\n`);

    // 4. 스키마 권한
    const schemaPrivs = await client.query(`
      SELECT 
        nspname as schema_name,
        pg_get_userbyid(nspowner) as owner,
        has_schema_privilege(current_user, nspname, 'CREATE') as can_create,
        has_schema_privilege(current_user, nspname, 'USAGE') as can_usage
      FROM pg_namespace
      WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      ORDER BY nspname
    `);
    console.log('4. 스키마 권한:');
    schemaPrivs.rows.forEach(row => {
      console.log(`   - ${row.schema_name}:`);
      console.log(`     소유자: ${row.owner}`);
      console.log(`     CREATE: ${row.can_create}`);
      console.log(`     USAGE: ${row.can_usage}`);
    });

    // 5. 기존 테이블 확인
    const tables = await client.query(`
      SELECT 
        schemaname,
        tablename,
        tableowner,
        has_table_privilege(current_user, schemaname||'.'||tablename, 'SELECT') as can_select,
        has_table_privilege(current_user, schemaname||'.'||tablename, 'INSERT') as can_insert,
        has_table_privilege(current_user, schemaname||'.'||tablename, 'UPDATE') as can_update,
        has_table_privilege(current_user, schemaname||'.'||tablename, 'DELETE') as can_delete
      FROM pg_tables
      WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      ORDER BY schemaname, tablename
    `);
    console.log('\n5. 테이블 권한:');
    if (tables.rows.length === 0) {
      console.log('   (테이블 없음)');
    } else {
      tables.rows.forEach(row => {
        console.log(`   - ${row.schemaname}.${row.tablename}:`);
        console.log(`     소유자: ${row.tableowner}`);
        console.log(`     권한: SELECT=${row.can_select}, INSERT=${row.can_insert}, UPDATE=${row.can_update}, DELETE=${row.can_delete}`);
      });
    }

    // 6. 부여된 권한 목록
    const grants = await client.query(`
      SELECT 
        grantee,
        table_schema,
        table_name,
        privilege_type
      FROM information_schema.table_privileges
      WHERE grantee = current_user
      ORDER BY table_schema, table_name, privilege_type
    `);
    console.log('\n6. 부여된 테이블 권한 목록:');
    if (grants.rows.length === 0) {
      console.log('   (부여된 권한 없음)');
    } else {
      grants.rows.forEach(row => {
        console.log(`   - ${row.table_schema}.${row.table_name}: ${row.privilege_type}`);
      });
    }

    // 7. 권한 요약
    console.log('\n========================================');
    console.log('  권한 요약');
    console.log('========================================');
    console.log(`✅ 데이터베이스 접속: 가능`);
    console.log(`${dbPriv.can_create ? '✅' : '❌'} 객체 생성: ${dbPriv.can_create ? '가능' : '불가'}`);
    
    const publicSchema = schemaPrivs.rows.find(r => r.schema_name === 'public');
    if (publicSchema) {
      console.log(`${publicSchema.can_create ? '✅' : '❌'} public 스키마에 테이블 생성: ${publicSchema.can_create ? '가능' : '불가'}`);
    }

    // 권한 기록 파일 생성
    const report = {
      timestamp: new Date().toISOString(),
      user: 'techb_pp',
      database: 'productparser_db',
      permissions: {
        database: dbPriv,
        schemas: schemaPrivs.rows,
        tables: tables.rows,
        grants: grants.rows
      }
    };

    require('fs').writeFileSync(
      'techb_pp_permissions.json',
      JSON.stringify(report, null, 2)
    );
    console.log('\n📄 권한 정보가 techb_pp_permissions.json 파일에 저장되었습니다.');

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error('상세:', error);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
checkTechbPPPermissions();