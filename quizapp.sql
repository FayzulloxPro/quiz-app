PGDMP                         {            quizapp    13.1    13.1 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    25564    quizapp    DATABASE     k   CREATE DATABASE quizapp WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'English_United States.1251';
    DROP DATABASE quizapp;
                postgres    false                        2615    25566    app    SCHEMA        CREATE SCHEMA app;
    DROP SCHEMA app;
                postgres    false                        2615    26256    auth    SCHEMA        CREATE SCHEMA auth;
    DROP SCHEMA auth;
                postgres    false            
            2615    26265    crud    SCHEMA        CREATE SCHEMA crud;
    DROP SCHEMA crud;
                postgres    false                        2615    26337 
   log_tables    SCHEMA        CREATE SCHEMA log_tables;
    DROP SCHEMA log_tables;
                postgres    false                        2615    25565    mappers    SCHEMA        CREATE SCHEMA mappers;
    DROP SCHEMA mappers;
                postgres    false                        2615    26260    my_utils    SCHEMA        CREATE SCHEMA my_utils;
    DROP SCHEMA my_utils;
                postgres    false                        2615    25567    utils    SCHEMA        CREATE SCHEMA utils;
    DROP SCHEMA utils;
                postgres    false                        3079    25568    pgcrypto 	   EXTENSION     ;   CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA utils;
    DROP EXTENSION pgcrypto;
                   false    6            �           0    0    EXTENSION pgcrypto    COMMENT     <   COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';
                        false    2            �           1247    25607    auth_register_dto    TYPE     �   CREATE TYPE app.auth_register_dto AS (
	fullname character varying,
	email character varying,
	username character varying,
	password character varying,
	role character varying
);
 !   DROP TYPE app.auth_register_dto;
       app          postgres    false    11            (           1255    26318    find_creator_of_subject(bigint)    FUNCTION       CREATE FUNCTION app.find_creator_of_subject(subject_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
creator_id bigint;
begin
    select created_by into creator_id from app.subject where id = subject_id;
    return creator_id;
end;
$$;
 >   DROP FUNCTION app.find_creator_of_subject(subject_id bigint);
       app          postgres    false    11                       1255    26380    get_correct_answer_id(bigint)    FUNCTION     ]  CREATE FUNCTION app.get_correct_answer_id(answerid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
    res record;
    t_id bigint;
begin

    select question_z_id into t_id from app.answers where id = answerId;
    select * into res from app.answers a where a.question_z_id=t_id and a.is_correct;
    return res.id;
end
$$;
 :   DROP FUNCTION app.get_correct_answer_id(answerid bigint);
       app          postgres    false    11            3           1255    26335    question_options(bigint)    FUNCTION     `  CREATE FUNCTION app.question_options(questionz_id bigint) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare

begin
    return coalesce((select json_agg(jsonb_build_object(
        'id',a.id,
        'option_text', a.answer_contest
        ))
            from app.answers a where a.question_z_id=questionZ_id
        ),'[]'::json);
end
$$;
 9   DROP FUNCTION app.question_options(questionz_id bigint);
       app          postgres    false    11                       1255    26257 0   auth_login(character varying, character varying)    FUNCTION     /  CREATE FUNCTION auth.auth_login(uname character varying DEFAULT NULL::character varying, pswd character varying DEFAULT NULL::character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
begin

    select * into t_user from app.users t where t.username ilike uname and is_deleted  = false;
    if not FOUND then
        raise exception 'User not found by username ''%''',uname;
    end if;

    if utils.match_password(pswd, t_user.password) is false then
        raise exception 'Bad credentials';
    end if;
    return json_build_object('id', t_user.id,
                               'fullname', t_user.fullname,
                               'username', t_user.username,
                               'email', t_user.email,
                               'language_id', t_user.language_id,
                               'role', t_user.role,
                               'created_at', t_user.created_at,
                               'updated_at', coalesce(t_user.updated_at::text, ''::text))::text;

end
$$;
 P   DROP FUNCTION auth.auth_login(uname character varying, pswd character varying);
       auth          postgres    false    13                       1255    26258    auth_register(text)    FUNCTION     Z  CREATE FUNCTION auth.auth_register(dataparam text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newId    int4;
    dataJson json;
    t_user   record;
    v_dto    app.auth_register_dto;
begin
    if dataparam isnull or dataparam = '{}'::text then
        raise exception 'Data param can not be null';
    end if;

    dataJson := dataparam::json;
    v_dto := mappers.json_to_auth_register_dto(dataJson);

    if v_dto.username is null or trim(v_dto.username) = '' then
        raise exception 'Username is invalid';
    end if;

    if v_dto.email is null or trim(v_dto.email) = '' then
        raise exception 'Email is invalid';
    end if;


    if utils.check_email(v_dto.email) is false then
        raise exception 'Email is invalid';
    end if;

    select * into t_user from app.users t where t.username ilike v_dto.username and is_deleted = false;
    if FOUND then
        raise exception 'Username ''%'' already taken',t_user.username;
    end if;

    select * into t_user from app.users t where t.email ilike v_dto.email and is_deleted = false;
    if FOUND then
        raise exception 'Email ''%'' already taken',t_user.email;
    end if;

    if v_dto.password is null or trim(v_dto.password) = '' then
        raise exception 'Password is invalid';
    end if;

    insert into app.users (fullname,username, password, email, role)
    values (v_dto.fullname,
            v_dto.username,
            utils.encode_password(v_dto.password),
            v_dto.email,
            v_dto.role)
    returning id into newId;
    return newId;
end
$$;
 2   DROP FUNCTION auth.auth_register(dataparam text);
       auth          postgres    false    13            &           1255    26259 +   auth_user_update(character varying, bigint)    FUNCTION     }  CREATE FUNCTION auth.auth_user_update(dataparam character varying DEFAULT NULL::character varying, userid bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    dataJson   json;
    t_user     record;
    v_fullname varchar;
    v_username varchar;
    v_email    varchar;
    v_role     varchar;
    v_language_id bigint;
    v_id       bigint;
begin

    call my_utils.isactive(userid);

    if dataparam is null or dataparam = '{}'::text then
        raise exception 'Dataparam can not be null';
    end if;

    dataJson := dataparam::json;

    v_id := dataJson ->> 'id';
    v_fullname := dataJson ->> 'fullname';
    v_username := dataJson ->> 'username';
    v_email := dataJson ->> 'email';
    v_language_id := dataJson ->> 'language_id';
    v_role := dataJson ->> 'role';

    if v_id != userid and my_utils.hasRole(userid, 'ADMIN') is false then
        raise exception 'Permission denied';
    end if;
    -- TODO check username, password, email, role

    if utils.check_email(v_email) is false then
        raise exception 'Email invalid ''%''', v_email;
    end if;

    select * into t_user from app.users t where t.is_deleted = false and t.id = v_id;
    if not FOUND then
        raise exception 'User not found by id ''%''',v_id;
    end if;

    if v_fullname is null then
        v_fullname := t_user.fullname;
    end if;
    if v_username is null then
        v_username := t_user.username;
    end if;
    if v_email is null then
        v_email := t_user.email;
    end if;
    if v_role is null then
        v_role := t_user.role;
    end if;
    if v_language_id is null then
        v_language_id := t_user.language_id;
    end if;

    update app.users
    set fullname = v_fullname,
        username = v_username,
        role     = v_role,
        language_id = v_language_id,
        email    = v_email
    where id = v_id;

    return true;
end
$$;
 Q   DROP FUNCTION auth.auth_user_update(dataparam character varying, userid bigint);
       auth          postgres    false    13            /           1255    26326    add_answers(text, bigint)    FUNCTION     �  CREATE FUNCTION crud.add_answers(dataparam text, questionzid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    options_json json;
    answer json;
begin
    options_json := dataParam::json;

    
    for answer in select json_array_elements((options_json->'answers')::json) loop
        insert into app.answers (question_z_id, answer_contest, is_correct) values (questionZid, answer->>'option', (answer->>'is_correct')::boolean);
        end loop;
    return true;
end
$$;
 D   DROP FUNCTION crud.add_answers(dataparam text, questionzid bigint);
       crud          postgres    false    10            '           1255    26282 M   addsubject_z(character varying, character varying, character varying, bigint) 	   PROCEDURE     k  CREATE PROCEDURE crud.addsubject_z(uz_name character varying, ru_name character varying, en_name character varying, subjectid bigint)
    LANGUAGE plpgsql
    AS $$
declare

begin
   if uz_name is not null and uz_name<>'' then
       insert into app.subject_z (subject_id, name) values (subjectId, uz_name);
   end if;
   if ru_name is not null and ru_name<>'' then
       insert into app.subject_z (subject_id, name) values (subjectId, ru_name);
   end if;
   if en_name is not null and en_name<>'' then
       insert into app.subject_z (subject_id, name) values (subjectId, en_name);
   end if;
end
$$;
 �   DROP PROCEDURE crud.addsubject_z(uz_name character varying, ru_name character varying, en_name character varying, subjectid bigint);
       crud          postgres    false    10            :           1255    26381 $   create_answers_history(text, bigint)    FUNCTION     )  CREATE FUNCTION crud.create_answers_history(dataparam text, userid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
    quizId          bigint;
    answerId        bigint;
    data_json       json;
    correctAnswerId bigint;
    res             bigint;
begin
    call my_utils.isdataparamnull(dataparam);
    data_json := dataparam::json;

    quizId := data_json ->> 'quiz_id';
    call my_utils.checkparamisnull(quizId, 'Quiz id');

    answerId := data_json ->> 'answer_id';
    call my_utils.checkparamisnull(answerId, 'Answer id');

    correctAnswerId := app.get_correct_answer_id(answerId);

    insert into app.answers_history(quiz_id, answer_id, correct_answer_id)
    values (quizId, answerId, correctAnswerId) returning id into res;
    
    return res;
--     TODO Fayzullo
end;
$$;
 J   DROP FUNCTION crud.create_answers_history(dataparam text, userid bigint);
       crud          postgres    false    10            $           1255    26271 *   create_language(character varying, bigint)    FUNCTION        CREATE FUNCTION crud.create_language(lang character varying, userid bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare declare
    newId bigint;
begin

    if lang is null or length(trim(lang)) = 0 then
        raise exception 'Name cannot be empty';
    end if;

    if userId isnull then
        raise 'User id is null';
    end if;

--     faqat admin rolidagi user yangi fan qo'sha oladi
    call my_utils.hasrole(userId, 'ADMIN');

    if exists(select * from app.language t where lower(t.name) = lower(lang)) then
        raise exception 'This language already exists ''%''',lang;
    end if;

    insert into app.language(name)
    values (lang)
    returning id into newId;

    return newId;
end;
$$;
 K   DROP FUNCTION crud.create_language(lang character varying, userid bigint);
       crud          postgres    false    10            )           1255    26319    create_level(character varying) 	   PROCEDURE       CREATE PROCEDURE crud.create_level(name character varying)
    LANGUAGE plpgsql
    AS $$
    begin
        if name is null then
            raise exception 'Enter to create';
        end if;
        insert
        into app.levels(title)
        VALUES (name);
    end;
$$;
 :   DROP PROCEDURE crud.create_level(name character varying);
       crud          postgres    false    10            0           1255    26310    create_question(text, bigint)    FUNCTION     Q  CREATE FUNCTION crud.create_question(dataparam text, userid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare

    data_json  json;
    questionId bigint;
    subjectId  bigint;
    levelId    bigint;
    lang_id    bigint;
    context    text;
    b          boolean;

begin

    call my_utils.isdataparamnull(dataparam);

    if (my_utils.hasrole(userId, 'ADMIN')
        or my_utils.hasrole(userId, 'MENTOR')) is not true then
        raise exception 'Access denied to add new question';
    end if;

    data_json := dataparam::json;
    questionId := data_json ->> 'question_id';
    subjectId := data_json ->> 'subject_id';
    levelId := data_json ->> 'level_id';
    lang_id := data_json ->> 'language_id';
    context := data_json ->> 'context';
--     options := data_json ->> 'answers';

    call my_utils.checkparamisnull(lang_id::text, 'Language id');
    call my_utils.checkparamisnull(context::text, 'Context');
--     call my_utils.checkparamisnull(options::text, 'Options');


    if questionId isnull then
        insert into app.question (subject_id, level_id) values (subjectId, levelId) returning id into questionId;
    end if;

    raise info 'in create question %',questionId;

    raise info 'working.................';

    select crud.questionZinsert(dataparam, questionId, userid) into b;

    return questionId;
end
$$;
 C   DROP FUNCTION crud.create_question(dataparam text, userid bigint);
       crud          postgres    false    10            4           1255    26336    create_quiz(text, bigint)    FUNCTION     ;  CREATE FUNCTION crud.create_quiz(dataparam text, userid bigint) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare
    languageId        bigint;
    levelId           bigint;
    subjectId         bigint;
    numberOfQuestions int4;
    data_json         json;
    result            json;
    newQuizId         bigint;
    all_questions     json;
begin
    call my_utils.isdataparamnull(dataparam);
    data_json := dataparam::json;

    call my_utils.isactive(userId);

    languageId := data_json ->> 'language_id';
    call my_utils.checkparamisnull(languageId::text, 'Language id');

    levelId := data_json ->> 'level_id';
    call my_utils.checkparamisnull(levelId::text, 'Level id');

    subjectId := data_json ->> 'subject_id';
    call my_utils.checkparamisnull(subjectId::text, 'Subject id');

    numberOfQuestions := data_json ->> 'number_of_questions';
    call my_utils.checkparamisnull(numberOfQuestions::text, 'Number of questions');

    raise info '% 2 ',1;
    
    insert into app.quiz (user_id, subject_id, level_id)
    values (userId, subjectId, levelId)
    returning id into newQuizId;

    all_questions := json_agg(jsonb_build_object(
            'question_id', t.id,
            'context_question', t.context,
            'answers', app.question_options(t.id)
        ))
                     from app.question_z t
                              join app.question q on q.id = t.question_id
                     where language_id = languageId
                       and q.level_id = levelId
                       and q.subject_id = subjectId
                     order by random()
                     limit abs(numberOfQuestions);

    raise info '% 33 ',1;
    result := jsonb_build_object(
            'quiz_id', newQuizId,
            'questions', coalesce(all_questions, '[]')
        );

    return result;
end;
$$;
 ?   DROP FUNCTION crud.create_quiz(dataparam text, userid bigint);
       crud          postgres    false    10            +           1255    26292    create_subject(text, bigint)    FUNCTION       CREATE FUNCTION crud.create_subject(dataparam text DEFAULT NULL::text, userid bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
    newSubjectId     bigint;
    uz_name   varchar;
    ru_name   varchar;
    en_name   varchar;
    data_json json;
begin
    call my_utils.isdataparamnull(dataParam);
    data_json:=dataParam::json;

    call my_utils.isactive(userid);

    if my_utils.hasrole(userid, 'ADMIN') is false and my_utils.hasrole(userid, 'MENTOR') is not true then
        raise exception 'Access denied for adding new subject';
    end if;

    uz_name:=data_json->>'uz_name';
    ru_name:=data_json->>'ru_name';
    en_name:=data_json->>'en_name';



    if ((uz_name is null or trim(uz_name)='')
            and (ru_name is null or trim(ru_name)='')
            and (en_name is null or trim(en_name)='')) then
        raise exception 'Name cannot be empty';
    end if;

    if exists(select * from app.subject_z where lower(name) = lower(uz_name))then
        raise exception 'This subject already exists ''%''', coalesce(uz_name, ru_name, en_name);
    end if;

    insert into app.subject(created_by)
    values (userid)
    returning id into newSubjectId;

    call crud.addsubject_z(uz_name, ru_name, en_name,newSubjectId);
    return newSubjectId;

end
$$;
 B   DROP FUNCTION crud.create_subject(dataparam text, userid bigint);
       crud          postgres    false    10            ,           1255    26320    delete_level(bigint)    FUNCTION     �  CREATE FUNCTION crud.delete_level(level_id bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    declare
        v_where app.levels%rowtype;
        v_check boolean default false;
    begin
        if level_id
            is null then
            raise exception 'Enter to delete';
        end if;
        select * into v_where from app.levels where id = level_id;
        if v_where is not null then
        raise exception 'Already exists';
        end if;
        update app.levels
        set is_deleted = true
        where id = level_id;

        select is_deleted into v_check from app.levels where id = level_id;
        return v_check;

    end;
$$;
 2   DROP FUNCTION crud.delete_level(level_id bigint);
       crud          postgres    false    10            -           1255    26321    delete_level(character varying)    FUNCTION     �  CREATE FUNCTION crud.delete_level(name_t character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    declare
        v_check boolean default false;
    begin
        if name_t
            is null then
            raise exception 'Enter to delete';
        end if;
        update app.levels
        set is_deleted = true
        where title = name_t;

        select is_deleted into v_check from app.levels where title = name_t;
        return v_check;

    end;
$$;
 ;   DROP FUNCTION crud.delete_level(name_t character varying);
       crud          postgres    false    10            *           1255    26327 %   questionzinsert(text, bigint, bigint)    FUNCTION     V  CREATE FUNCTION crud.questionzinsert(dataparam text DEFAULT NULL::text, questionid bigint DEFAULT NULL::bigint, userid bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
        b boolean;
        data_json   json;
        lang_id     bigint;
        t_context   text;
        questionZId bigint;
        temp_i      text;
        answersParam text;
    begin
        

        data_json := dataparam::json;
        lang_id := data_json ->> 'language_id';
        t_context := data_json ->> 'context';
        answersParam:=data_json->> 'answers';

        --     options := data_json ->> 'answers';
--     TODO check options are not null or empty

        raise info '%',questionId;
        
        insert into app.question_z (question_id, language_id, context)
        values (questionId, lang_id, t_context)
        returning id into questionZId;

        
        temp_i := data_json ->> 'answers';
        raise info using message = temp_i;


        select crud.add_answers(concat('{"answers":'||answersParam||'}'), questionZId) into b;
        return true;
    end
$$;
 V   DROP FUNCTION crud.questionzinsert(dataparam text, questionid bigint, userid bigint);
       crud          postgres    false    10            1           1255    26322    update_answers(text, bigint)    FUNCTION     -  CREATE FUNCTION crud.update_answers(dataparam text, userid bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    dataJson         json;
    t_answer         record;
    v_answer_contest text;
    v_question_id    bigint;
    v_is_correct     boolean;
    v_id             bigint;
begin
    --     TODO check again

    if my_utils.hasrole(userId, 'ADMIN') then

        if dataparam is null or dataparam = '{}'::text then
            raise exception 'DataParam can not be null';
        end if;


        dataJson := dataparam::json;

        v_id := dataJson ->> 'id';
        v_answer_contest := dataJson ->> 'answer_contest';
        v_question_id := dataJson ->> 'question_z_id';
        v_is_correct := dataJson ->> 'is_correct';

        select * into t_answer from app.answers where id = v_id;

        if not FOUND then
            raise exception 'Not found by ''%''',v_id;
        end if;

        if v_answer_contest is null or length(trim(v_answer_contest)) = 0 then
            v_answer_contest := t_answer.answer_contest;
        end if;

        if v_is_correct is null then
            v_is_correct := t_answer.is_correct;
        end if;

        if v_question_id is null then
            v_question_id := t_answer.question_z_id;
        end if;
        update app.answers
        set answer_contest= v_answer_contest,
            is_correct    =v_is_correct,
            question_z_id   = v_question_id
        where id = v_id;

        return true;
    else
        raise exception 'Update is not allowed';
    end if;
end;
$$;
 B   DROP FUNCTION crud.update_answers(dataparam text, userid bigint);
       crud          postgres    false    10            %           1255    26277    update_language(text, bigint)    FUNCTION     J  CREATE FUNCTION crud.update_language(dataparam text DEFAULT NULL::text, userid bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    language_id bigint;
    data_json   json;
    new_name    varchar;
begin
    call my_utils.isdataparamnull(dataParam);

    if my_utils.hasrole(userId, 'ADMIN') is false then
        raise exception 'Access denied';
    end if;
    data_json := dataParam::json;

    language_id := data_json ->> 'language_id';
    new_name := data_json ->> 'new_name';

    if language_id is null then
        raise exception 'Language id is null';
    end if;

    if new_name isnull or trim(new_name)='' then
        raise exception 'New name cannot be null';
    end if;

    update app.language set name=new_name where id=language_id;
    return true;
end
$$;
 C   DROP FUNCTION crud.update_language(dataparam text, userid bigint);
       crud          postgres    false    10            2           1255    26328    update_question(text, bigint)    FUNCTION     ^  CREATE FUNCTION crud.update_question(dataparam text, userid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
    questionZId bigint;
    newContext  text;
    languageId  bigint;
    data_json   json;
    t_questionZ app.question_z%rowtype;
begin
    call my_utils.isdataparamnull(dataparam);
    
    

    call my_utils.checkparamisnull(userId::text, 'User id'::varchar);
    if (my_utils.hasrole(userid, 'ADMIN') or my_utils.hasrole(userid, 'MENTOR')) is false then
        raise exception 'Access denied';
    end if;
    data_json := dataparam::json;


    questionZId := data_json ->> 'question_z_id';
    call my_utils.checkparamisnull(questionZId::text, 'Question id'::varchar);

    select * into t_questionZ from app.question_z t where t.id = questionZId;
    if not FOUND or t_questionZ.is_deleted then
        raise exception 'Question not found by id ''%''', questionZId;
    end if;

    languageId := data_json ->> 'language_id';
    if languageId isnull then
        languageId := t_questionZ.language_id;
    end if;

    newContext := data_json ->> 'context';
    if newContext is null or trim(newContext) = '' then
        newContext := t_questionZ.context;
    end if;

    update app.question_z
    set context=newContext,
        language_id=languageId,
        updated_at=now()
    where id = questionZId;
    return questionZId;
end
$$;
 C   DROP FUNCTION crud.update_question(dataparam text, userid bigint);
       crud          postgres    false    10            .           1255    26323    update_subject(text, integer)    FUNCTION     �  CREATE FUNCTION crud.update_subject(dataparam text, updater_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    dataJson     json;
    v_subject_id bigint;
    v_name       text;
    v_creater_id bigint;

begin

    call my_utils.isdataparamnull(dataparam);

    dataJson := dataparam::json;

    v_subject_id := dataJson ->> 'subject_id';
    v_creater_id := app.find_creator_of_subject(v_subject_id);
    v_name := json_build_array('name',dataJson ->> '_name');

--    crud.update_subject_z()
--------------------------------

    if v_creater_id != updater_id and
                (my_utils.hasRole(updater_id, 'ADMIN') or my_utils.hasRole(updater_id, 'MENTOR')) is false then
        raise exception 'Permission denied';
    end if;
    update app.subject
    set updated_at = now(),
        updated_by = v_creater_id
    where id = v_subject_id;

    return crud.update_subject_z(dataparam, updater_id);
-------------------

end;
$$;
 G   DROP FUNCTION crud.update_subject(dataparam text, updater_id integer);
       crud          postgres    false    10            9           1255    26351    tg_fun_users()    FUNCTION     7  CREATE FUNCTION log_tables.tg_fun_users() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

      insert into log_tables.log_users(t_name, operation_name, user_id, old_values, new_value, col_name)
      values (tg_table_name,tg_op,new.id,old.fullname,new.fullname,'fullname');
     return new;
    end;
$$;
 )   DROP FUNCTION log_tables.tg_fun_users();
    
   log_tables          postgres    false    5            5           1255    26360    tg_fun_users_email()    FUNCTION     A  CREATE FUNCTION log_tables.tg_fun_users_email() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

            insert into log_tables.log_users(t_name, operation_name, user_id, old_values, new_value, col_name)
            values (tg_table_name,tg_op,new.id,old.email,new.email,'email');
      return new;
    end;
$$;
 /   DROP FUNCTION log_tables.tg_fun_users_email();
    
   log_tables          postgres    false    5            6           1255    26362    tg_fun_users_language()    FUNCTION     V  CREATE FUNCTION log_tables.tg_fun_users_language() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

            insert into log_tables.log_users(t_name, operation_name, user_id, old_values, new_value, col_name)
            values (tg_table_name,tg_op,new.id,old.language_id,new.language_id,'language_id');
      return new;
    end;
$$;
 2   DROP FUNCTION log_tables.tg_fun_users_language();
    
   log_tables          postgres    false    5            7           1255    26361    tg_fun_users_password()    FUNCTION     M  CREATE FUNCTION log_tables.tg_fun_users_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

            insert into log_tables.log_users(t_name, operation_name, user_id, old_values, new_value, col_name)
            values (tg_table_name,tg_op,new.id,old.password,new.password,'password');
      return new;
    end;
$$;
 2   DROP FUNCTION log_tables.tg_fun_users_password();
    
   log_tables          postgres    false    5            8           1255    26359    tg_fun_users_username()    FUNCTION     d  CREATE FUNCTION log_tables.tg_fun_users_username() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
          
            insert into log_tables.log_users(t_name, operation_name, user_id, old_values, new_value, col_name)
            values (tg_table_name,tg_op,new.id,old.username,new.username,'username');
            
      return new;
    end;
$$;
 2   DROP FUNCTION log_tables.tg_fun_users_username();
    
   log_tables          postgres    false    5                       1255    25608    json_to_auth_register_dto(json)    FUNCTION     �  CREATE FUNCTION mappers.json_to_auth_register_dto(datajson json) RETURNS app.auth_register_dto
    LANGUAGE plpgsql
    AS $$
declare
    dto app.auth_register_dto;
begin
    dto.fullname := dataJson ->> 'fullname';
    dto.username := dataJson ->> 'username';
    dto.email := dataJson ->> 'email';
    dto.role := dataJson ->> 'role';
    dto.password := dataJson ->> 'password';
    return dto;
end
$$;
 @   DROP FUNCTION mappers.json_to_auth_register_dto(datajson json);
       mappers          postgres    false    726    7            #           1255    26315 )   checkparamisnull(text, character varying) 	   PROCEDURE     �   CREATE PROCEDURE my_utils.checkparamisnull(param text, paramname character varying)
    LANGUAGE plpgsql
    AS $$
begin
    if param isnull then
        raise exception using message =(paramname||' is null');
    end if;
end
$$;
 S   DROP PROCEDURE my_utils.checkparamisnull(param text, paramname character varying);
       my_utils          postgres    false    12                       1255    26261 "   hasrole(bigint, character varying)    FUNCTION     �  CREATE FUNCTION my_utils.hasrole(userid bigint DEFAULT NULL::bigint, role character varying DEFAULT NULL::character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
BEGIN
    if userid is null or role is null then
        return false;
    end if;
    select * into t_user from app.users t where t.is_deleted = false and t.id = userid;
    return FOUND and t_user.role = role;
END
$$;
 G   DROP FUNCTION my_utils.hasrole(userid bigint, role character varying);
       my_utils          postgres    false    12                        1255    26262    isactive(bigint) 	   PROCEDURE     �  CREATE PROCEDURE my_utils.isactive(userid bigint DEFAULT NULL::bigint)
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
BEGIN
    if userid is null then
        raise exception 'User id is null';
    end if;

    select * into t_user from app.users t where t.is_deleted = false and t.id = userid;
    if not FOUND then
        raise exception 'User not found by id : ''%''',userid;
    end if;
END
$$;
 1   DROP PROCEDURE my_utils.isactive(userid bigint);
       my_utils          postgres    false    12            !           1255    26263    isdataparamnull(text) 	   PROCEDURE     �   CREATE PROCEDURE my_utils.isdataparamnull(dataparam text DEFAULT NULL::text)
    LANGUAGE plpgsql
    AS $$
declare
begin
    if dataParam isnull or dataParam = '{}' then
        raise exception 'DataParam is empty';
    end if;
end
$$;
 9   DROP PROCEDURE my_utils.isdataparamnull(dataparam text);
       my_utils          postgres    false    12            "           1255    26264    userinfo(bigint)    FUNCTION     �  CREATE FUNCTION my_utils.userinfo(userid bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
    r_user record;
begin
    select * into r_user from app.users u where u.is_deleted = false and u.id = userid;
    if FOUND then
        return row_to_json(X)::jsonb
            FROM (SELECT r_user.id, r_user.fullname, r_user.username, r_user.email, r_user.language_id, r_user.role) AS X;
    else
        return null;
    end if;
end
$$;
 0   DROP FUNCTION my_utils.userinfo(userid bigint);
       my_utils          postgres    false    12                       1255    25626    check_email(character varying)    FUNCTION       CREATE FUNCTION utils.check_email(email character varying DEFAULT NULL::character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare
    pattern varchar := '^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-]+)(\.[a-zA-Z]{2,5}){1,2}$';
BEGIN
    return email ~* pattern;
END
$_$;
 :   DROP FUNCTION utils.check_email(email character varying);
       utils          postgres    false    6                       1255    25627 "   encode_password(character varying)    FUNCTION     '  CREATE FUNCTION utils.encode_password(rawpassword character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
begin
    if rawPassword is null then
        raise exception 'Invalid Password null';
    end if;
    return utils.crypt(rawPassword, utils.gen_salt('bf', 4));
end
$$;
 D   DROP FUNCTION utils.encode_password(rawpassword character varying);
       utils          postgres    false    6                       1255    25628 4   match_password(character varying, character varying)    FUNCTION     �  CREATE FUNCTION utils.match_password(rawpassword character varying, encodedpassword character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare

begin
    if rawPassword is null then
        raise exception 'Invalid Password null';
    end if;

    if encodedPassword is null then
        raise exception 'Invalid encoded Password null';
    end if;
    return encodedPassword = utils.crypt(rawPassword, encodedPassword);
end
$$;
 f   DROP FUNCTION utils.match_password(rawpassword character varying, encodedpassword character varying);
       utils          postgres    false    6            �            1259    26101    answers    TABLE     �   CREATE TABLE app.answers (
    id bigint NOT NULL,
    question_z_id bigint NOT NULL,
    answer_contest text NOT NULL,
    is_correct boolean DEFAULT false NOT NULL
);
    DROP TABLE app.answers;
       app         heap    postgres    false    11            �            1259    26114    answers_history    TABLE     �   CREATE TABLE app.answers_history (
    id bigint NOT NULL,
    quiz_id bigint NOT NULL,
    answer_id bigint NOT NULL,
    correct_answer_id bigint NOT NULL
);
     DROP TABLE app.answers_history;
       app         heap    postgres    false    11            �            1259    26223    answers_history_id_seq    SEQUENCE     |   CREATE SEQUENCE app.answers_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE app.answers_history_id_seq;
       app          postgres    false    11    217            �           0    0    answers_history_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE app.answers_history_id_seq OWNED BY app.answers_history.id;
          app          postgres    false    221            �            1259    26220    answers_id_seq    SEQUENCE     t   CREATE SEQUENCE app.answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE app.answers_id_seq;
       app          postgres    false    11    215            �           0    0    answers_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE app.answers_id_seq OWNED BY app.answers.id;
          app          postgres    false    220            �            1259    26083    language    TABLE     �   CREATE TABLE app.language (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);
    DROP TABLE app.language;
       app         heap    postgres    false    11            �            1259    26226    language_id_seq    SEQUENCE     u   CREATE SEQUENCE app.language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE app.language_id_seq;
       app          postgres    false    11    213            �           0    0    language_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE app.language_id_seq OWNED BY app.language.id;
          app          postgres    false    222            �            1259    26077    levels    TABLE     �   CREATE TABLE app.levels (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);
    DROP TABLE app.levels;
       app         heap    postgres    false    11            �            1259    26229    levels_id_seq    SEQUENCE     s   CREATE SEQUENCE app.levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE app.levels_id_seq;
       app          postgres    false    11    212            �           0    0    levels_id_seq    SEQUENCE OWNED BY     9   ALTER SEQUENCE app.levels_id_seq OWNED BY app.levels.id;
          app          postgres    false    223            �            1259    26072    question    TABLE     t   CREATE TABLE app.question (
    id bigint NOT NULL,
    subject_id bigint NOT NULL,
    level_id bigint NOT NULL
);
    DROP TABLE app.question;
       app         heap    postgres    false    11            �            1259    26232    question_id_seq    SEQUENCE     u   CREATE SEQUENCE app.question_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE app.question_id_seq;
       app          postgres    false    211    11            �           0    0    question_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE app.question_id_seq OWNED BY app.question.id;
          app          postgres    false    224            �            1259    26119 
   question_z    TABLE       CREATE TABLE app.question_z (
    id bigint NOT NULL,
    question_id bigint NOT NULL,
    language_id bigint NOT NULL,
    context text NOT NULL,
    is_deleted boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);
    DROP TABLE app.question_z;
       app         heap    postgres    false    11            �            1259    26238    question_z_id_seq    SEQUENCE     w   CREATE SEQUENCE app.question_z_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE app.question_z_id_seq;
       app          postgres    false    218    11            �           0    0    question_z_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE app.question_z_id_seq OWNED BY app.question_z.id;
          app          postgres    false    225            �            1259    26090    quiz    TABLE     1  CREATE TABLE app.quiz (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    level_id bigint NOT NULL,
    started_at timestamp(0) with time zone DEFAULT '2023-01-08 14:17:30.859421+05'::timestamp with time zone NOT NULL,
    finished_at timestamp(0) with time zone
);
    DROP TABLE app.quiz;
       app         heap    postgres    false    11            �            1259    26241    quiz_id_seq    SEQUENCE     q   CREATE SEQUENCE app.quiz_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
    DROP SEQUENCE app.quiz_id_seq;
       app          postgres    false    214    11            �           0    0    quiz_id_seq    SEQUENCE OWNED BY     5   ALTER SEQUENCE app.quiz_id_seq OWNED BY app.quiz.id;
          app          postgres    false    226            �            1259    26109    quiz_questions    TABLE     �   CREATE TABLE app.quiz_questions (
    id bigint NOT NULL,
    subject_id bigint NOT NULL,
    question_id bigint NOT NULL,
    quiz_id bigint NOT NULL
);
    DROP TABLE app.quiz_questions;
       app         heap    postgres    false    11            �            1259    26244    quiz_questions_id_seq    SEQUENCE     {   CREATE SEQUENCE app.quiz_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE app.quiz_questions_id_seq;
       app          postgres    false    11    216            �           0    0    quiz_questions_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE app.quiz_questions_id_seq OWNED BY app.quiz_questions.id;
          app          postgres    false    227            �            1259    26067    subject    TABLE     
  CREATE TABLE app.subject (
    id bigint NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp(0) with time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) with time zone,
    created_by bigint NOT NULL,
    updated_by bigint
);
    DROP TABLE app.subject;
       app         heap    postgres    false    11            �            1259    26247    subject_id_seq    SEQUENCE     t   CREATE SEQUENCE app.subject_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE app.subject_id_seq;
       app          postgres    false    210    11            �           0    0    subject_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE app.subject_id_seq OWNED BY app.subject.id;
          app          postgres    false    228            �            1259    26127 	   subject_z    TABLE     |   CREATE TABLE app.subject_z (
    id bigint NOT NULL,
    subject_id bigint NOT NULL,
    name character varying NOT NULL
);
    DROP TABLE app.subject_z;
       app         heap    postgres    false    11            �            1259    26250    subject_z_id_seq    SEQUENCE     v   CREATE SEQUENCE app.subject_z_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE app.subject_z_id_seq;
       app          postgres    false    11    219            �           0    0    subject_z_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE app.subject_z_id_seq OWNED BY app.subject_z.id;
          app          postgres    false    229            �            1259    26056    users    TABLE     >  CREATE TABLE app.users (
    id bigint NOT NULL,
    fullname character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    username character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    role character varying(255) NOT NULL,
    created_at timestamp(0) with time zone DEFAULT '2023-01-08 14:17:30.147487+05'::timestamp with time zone NOT NULL,
    updated_at timestamp(0) with time zone,
    language_id bigint DEFAULT 1 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    is_blocked boolean DEFAULT false NOT NULL
);
    DROP TABLE app.users;
       app         heap    postgres    false    11            �            1259    26253    users_id_seq    SEQUENCE     r   CREATE SEQUENCE app.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
     DROP SEQUENCE app.users_id_seq;
       app          postgres    false    209    11            �           0    0    users_id_seq    SEQUENCE OWNED BY     7   ALTER SEQUENCE app.users_id_seq OWNED BY app.users.id;
          app          postgres    false    230            �            1259    26340 	   log_users    TABLE     K  CREATE TABLE log_tables.log_users (
    id bigint NOT NULL,
    t_name character varying NOT NULL,
    operation_name character varying NOT NULL,
    user_id bigint,
    old_values character varying,
    new_value character varying,
    col_name character varying,
    changed_at timestamp with time zone DEFAULT now() NOT NULL
);
 !   DROP TABLE log_tables.log_users;
    
   log_tables         heap    postgres    false    5            �            1259    26338    log_users_id_seq    SEQUENCE     }   CREATE SEQUENCE log_tables.log_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE log_tables.log_users_id_seq;
    
   log_tables          postgres    false    232    5            �           0    0    log_users_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE log_tables.log_users_id_seq OWNED BY log_tables.log_users.id;
       
   log_tables          postgres    false    231            �           2604    26222 
   answers id    DEFAULT     b   ALTER TABLE ONLY app.answers ALTER COLUMN id SET DEFAULT nextval('app.answers_id_seq'::regclass);
 6   ALTER TABLE app.answers ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    220    215            �           2604    26225    answers_history id    DEFAULT     r   ALTER TABLE ONLY app.answers_history ALTER COLUMN id SET DEFAULT nextval('app.answers_history_id_seq'::regclass);
 >   ALTER TABLE app.answers_history ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    221    217            �           2604    26228    language id    DEFAULT     d   ALTER TABLE ONLY app.language ALTER COLUMN id SET DEFAULT nextval('app.language_id_seq'::regclass);
 7   ALTER TABLE app.language ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    222    213            �           2604    26231 	   levels id    DEFAULT     `   ALTER TABLE ONLY app.levels ALTER COLUMN id SET DEFAULT nextval('app.levels_id_seq'::regclass);
 5   ALTER TABLE app.levels ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    223    212            �           2604    26234    question id    DEFAULT     d   ALTER TABLE ONLY app.question ALTER COLUMN id SET DEFAULT nextval('app.question_id_seq'::regclass);
 7   ALTER TABLE app.question ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    224    211            �           2604    26240    question_z id    DEFAULT     h   ALTER TABLE ONLY app.question_z ALTER COLUMN id SET DEFAULT nextval('app.question_z_id_seq'::regclass);
 9   ALTER TABLE app.question_z ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    225    218            �           2604    26243    quiz id    DEFAULT     \   ALTER TABLE ONLY app.quiz ALTER COLUMN id SET DEFAULT nextval('app.quiz_id_seq'::regclass);
 3   ALTER TABLE app.quiz ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    226    214            �           2604    26246    quiz_questions id    DEFAULT     p   ALTER TABLE ONLY app.quiz_questions ALTER COLUMN id SET DEFAULT nextval('app.quiz_questions_id_seq'::regclass);
 =   ALTER TABLE app.quiz_questions ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    227    216            �           2604    26249 
   subject id    DEFAULT     b   ALTER TABLE ONLY app.subject ALTER COLUMN id SET DEFAULT nextval('app.subject_id_seq'::regclass);
 6   ALTER TABLE app.subject ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    228    210            �           2604    26252    subject_z id    DEFAULT     f   ALTER TABLE ONLY app.subject_z ALTER COLUMN id SET DEFAULT nextval('app.subject_z_id_seq'::regclass);
 8   ALTER TABLE app.subject_z ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    229    219            �           2604    26255    users id    DEFAULT     ^   ALTER TABLE ONLY app.users ALTER COLUMN id SET DEFAULT nextval('app.users_id_seq'::regclass);
 4   ALTER TABLE app.users ALTER COLUMN id DROP DEFAULT;
       app          postgres    false    230    209            �           2604    26343    log_users id    DEFAULT     t   ALTER TABLE ONLY log_tables.log_users ALTER COLUMN id SET DEFAULT nextval('log_tables.log_users_id_seq'::regclass);
 ?   ALTER TABLE log_tables.log_users ALTER COLUMN id DROP DEFAULT;
    
   log_tables          postgres    false    231    232    232            �          0    26101    answers 
   TABLE DATA           M   COPY app.answers (id, question_z_id, answer_contest, is_correct) FROM stdin;
    app          postgres    false    215   r      �          0    26114    answers_history 
   TABLE DATA           Q   COPY app.answers_history (id, quiz_id, answer_id, correct_answer_id) FROM stdin;
    app          postgres    false    217   �      �          0    26083    language 
   TABLE DATA           5   COPY app.language (id, name, is_deleted) FROM stdin;
    app          postgres    false    213   �      �          0    26077    levels 
   TABLE DATA           4   COPY app.levels (id, title, is_deleted) FROM stdin;
    app          postgres    false    212         �          0    26072    question 
   TABLE DATA           9   COPY app.question (id, subject_id, level_id) FROM stdin;
    app          postgres    false    211   2      �          0    26119 
   question_z 
   TABLE DATA           l   COPY app.question_z (id, question_id, language_id, context, is_deleted, created_at, updated_at) FROM stdin;
    app          postgres    false    218   Y      �          0    26090    quiz 
   TABLE DATA           W   COPY app.quiz (id, user_id, subject_id, level_id, started_at, finished_at) FROM stdin;
    app          postgres    false    214   �      �          0    26109    quiz_questions 
   TABLE DATA           K   COPY app.quiz_questions (id, subject_id, question_id, quiz_id) FROM stdin;
    app          postgres    false    216          �          0    26067    subject 
   TABLE DATA           ^   COPY app.subject (id, is_deleted, created_at, updated_at, created_by, updated_by) FROM stdin;
    app          postgres    false    210   =      �          0    26127 	   subject_z 
   TABLE DATA           6   COPY app.subject_z (id, subject_id, name) FROM stdin;
    app          postgres    false    219   {      �          0    26056    users 
   TABLE DATA           �   COPY app.users (id, fullname, email, username, password, role, created_at, updated_at, language_id, is_deleted, is_blocked) FROM stdin;
    app          postgres    false    209   �      �          0    26340 	   log_users 
   TABLE DATA           y   COPY log_tables.log_users (id, t_name, operation_name, user_id, old_values, new_value, col_name, changed_at) FROM stdin;
 
   log_tables          postgres    false    232   �      �           0    0    answers_history_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('app.answers_history_id_seq', 1, false);
          app          postgres    false    221            �           0    0    answers_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('app.answers_id_seq', 50, true);
          app          postgres    false    220            �           0    0    language_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('app.language_id_seq', 4, true);
          app          postgres    false    222            �           0    0    levels_id_seq    SEQUENCE SET     8   SELECT pg_catalog.setval('app.levels_id_seq', 1, true);
          app          postgres    false    223            �           0    0    question_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('app.question_id_seq', 15, true);
          app          postgres    false    224            �           0    0    question_z_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('app.question_z_id_seq', 32, true);
          app          postgres    false    225            �           0    0    quiz_id_seq    SEQUENCE SET     6   SELECT pg_catalog.setval('app.quiz_id_seq', 3, true);
          app          postgres    false    226            �           0    0    quiz_questions_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('app.quiz_questions_id_seq', 1, false);
          app          postgres    false    227            �           0    0    subject_id_seq    SEQUENCE SET     9   SELECT pg_catalog.setval('app.subject_id_seq', 2, true);
          app          postgres    false    228            �           0    0    subject_z_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('app.subject_z_id_seq', 3, true);
          app          postgres    false    229            �           0    0    users_id_seq    SEQUENCE SET     8   SELECT pg_catalog.setval('app.users_id_seq', 44, true);
          app          postgres    false    230            �           0    0    log_users_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('log_tables.log_users_id_seq', 25, true);
       
   log_tables          postgres    false    231            �           2606    26118 $   answers_history answers_history_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY app.answers_history
    ADD CONSTRAINT answers_history_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY app.answers_history DROP CONSTRAINT answers_history_pkey;
       app            postgres    false    217            �           2606    26108    answers answers_pkey 
   CONSTRAINT     O   ALTER TABLE ONLY app.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (id);
 ;   ALTER TABLE ONLY app.answers DROP CONSTRAINT answers_pkey;
       app            postgres    false    215            �           2606    26089    language language_name_unique 
   CONSTRAINT     U   ALTER TABLE ONLY app.language
    ADD CONSTRAINT language_name_unique UNIQUE (name);
 D   ALTER TABLE ONLY app.language DROP CONSTRAINT language_name_unique;
       app            postgres    false    213            �           2606    26087    language language_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY app.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY app.language DROP CONSTRAINT language_pkey;
       app            postgres    false    213            �           2606    26082    levels levels_pkey 
   CONSTRAINT     M   ALTER TABLE ONLY app.levels
    ADD CONSTRAINT levels_pkey PRIMARY KEY (id);
 9   ALTER TABLE ONLY app.levels DROP CONSTRAINT levels_pkey;
       app            postgres    false    212            �           2606    26076    question question_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY app.question
    ADD CONSTRAINT question_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY app.question DROP CONSTRAINT question_pkey;
       app            postgres    false    211            �           2606    26126    question_z question_z_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY app.question_z
    ADD CONSTRAINT question_z_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY app.question_z DROP CONSTRAINT question_z_pkey;
       app            postgres    false    218            �           2606    26312 1   question_z question_z_question_id_language_id_key 
   CONSTRAINT     }   ALTER TABLE ONLY app.question_z
    ADD CONSTRAINT question_z_question_id_language_id_key UNIQUE (question_id, language_id);
 X   ALTER TABLE ONLY app.question_z DROP CONSTRAINT question_z_question_id_language_id_key;
       app            postgres    false    218    218            �           2606    26095    quiz quiz_pkey 
   CONSTRAINT     I   ALTER TABLE ONLY app.quiz
    ADD CONSTRAINT quiz_pkey PRIMARY KEY (id);
 5   ALTER TABLE ONLY app.quiz DROP CONSTRAINT quiz_pkey;
       app            postgres    false    214            �           2606    26113 "   quiz_questions quiz_questions_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY app.quiz_questions
    ADD CONSTRAINT quiz_questions_pkey PRIMARY KEY (id);
 I   ALTER TABLE ONLY app.quiz_questions DROP CONSTRAINT quiz_questions_pkey;
       app            postgres    false    216            �           2606    26071    subject subject_pkey 
   CONSTRAINT     O   ALTER TABLE ONLY app.subject
    ADD CONSTRAINT subject_pkey PRIMARY KEY (id);
 ;   ALTER TABLE ONLY app.subject DROP CONSTRAINT subject_pkey;
       app            postgres    false    210            �           2606    26294    subject_z subject_z_name_unique 
   CONSTRAINT     W   ALTER TABLE ONLY app.subject_z
    ADD CONSTRAINT subject_z_name_unique UNIQUE (name);
 F   ALTER TABLE ONLY app.subject_z DROP CONSTRAINT subject_z_name_unique;
       app            postgres    false    219            �           2606    26131    subject_z subject_z_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY app.subject_z
    ADD CONSTRAINT subject_z_pkey PRIMARY KEY (id);
 ?   ALTER TABLE ONLY app.subject_z DROP CONSTRAINT subject_z_pkey;
       app            postgres    false    219            �           2606    26066    users users_pkey 
   CONSTRAINT     K   ALTER TABLE ONLY app.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 7   ALTER TABLE ONLY app.users DROP CONSTRAINT users_pkey;
       app            postgres    false    209            �           2606    26349    log_users log_users_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY log_tables.log_users
    ADD CONSTRAINT log_users_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY log_tables.log_users DROP CONSTRAINT log_users_pkey;
    
   log_tables            postgres    false    232                       2620    26370    users tg_user_email    TRIGGER     �   CREATE TRIGGER tg_user_email AFTER INSERT OR UPDATE OF language_id ON app.users FOR EACH ROW EXECUTE FUNCTION log_tables.tg_fun_users_email();
 )   DROP TRIGGER tg_user_email ON app.users;
       app          postgres    false    209    209    309            	           2620    26373    users tg_user_fullname    TRIGGER     �   CREATE TRIGGER tg_user_fullname AFTER INSERT OR UPDATE OF fullname ON app.users FOR EACH ROW EXECUTE FUNCTION log_tables.tg_fun_users();
 ,   DROP TRIGGER tg_user_fullname ON app.users;
       app          postgres    false    209    209    313                       2620    26368    users tg_user_language    TRIGGER     �   CREATE TRIGGER tg_user_language AFTER INSERT OR UPDATE OF language_id ON app.users FOR EACH ROW EXECUTE FUNCTION log_tables.tg_fun_users_language();
 ,   DROP TRIGGER tg_user_language ON app.users;
       app          postgres    false    209    310    209                       2620    26367    users tg_user_password    TRIGGER     �   CREATE TRIGGER tg_user_password AFTER INSERT OR UPDATE OF password ON app.users FOR EACH ROW EXECUTE FUNCTION log_tables.tg_fun_users_password();
 ,   DROP TRIGGER tg_user_password ON app.users;
       app          postgres    false    209    209    311                       2620    26366    users tg_user_username    TRIGGER     �   CREATE TRIGGER tg_user_username AFTER INSERT OR UPDATE OF username ON app.users FOR EACH ROW EXECUTE FUNCTION log_tables.tg_fun_users_username();
 ,   DROP TRIGGER tg_user_username ON app.users;
       app          postgres    false    209    312    209                       2606    26209 1   answers_history answers_history_answer_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.answers_history
    ADD CONSTRAINT answers_history_answer_id_foreign FOREIGN KEY (answer_id) REFERENCES app.answers(id);
 X   ALTER TABLE ONLY app.answers_history DROP CONSTRAINT answers_history_answer_id_foreign;
       app          postgres    false    217    215    3044                        2606    26204 /   answers_history answers_history_quiz_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.answers_history
    ADD CONSTRAINT answers_history_quiz_id_foreign FOREIGN KEY (quiz_id) REFERENCES app.quiz(id);
 V   ALTER TABLE ONLY app.answers_history DROP CONSTRAINT answers_history_quiz_id_foreign;
       app          postgres    false    217    214    3042            �           2606    26214 #   answers answers_question_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.answers
    ADD CONSTRAINT answers_question_id_foreign FOREIGN KEY (question_z_id) REFERENCES app.question_z(id);
 J   ALTER TABLE ONLY app.answers DROP CONSTRAINT answers_question_id_foreign;
       app          postgres    false    3050    215    218            �           2606    26374 "   answers_history fk_answers_history    FK CONSTRAINT     �   ALTER TABLE ONLY app.answers_history
    ADD CONSTRAINT fk_answers_history FOREIGN KEY (correct_answer_id) REFERENCES app.question_z(id);
 I   ALTER TABLE ONLY app.answers_history DROP CONSTRAINT fk_answers_history;
       app          postgres    false    3050    218    217            �           2606    26329 )   quiz_questions fk_quiz_questions_question    FK CONSTRAINT     �   ALTER TABLE ONLY app.quiz_questions
    ADD CONSTRAINT fk_quiz_questions_question FOREIGN KEY (question_id) REFERENCES app.question(id);
 P   ALTER TABLE ONLY app.quiz_questions DROP CONSTRAINT fk_quiz_questions_question;
       app          postgres    false    3034    216    211            �           2606    26174 "   question question_level_id_foreign    FK CONSTRAINT     }   ALTER TABLE ONLY app.question
    ADD CONSTRAINT question_level_id_foreign FOREIGN KEY (level_id) REFERENCES app.levels(id);
 I   ALTER TABLE ONLY app.question DROP CONSTRAINT question_level_id_foreign;
       app          postgres    false    211    212    3036            �           2606    26159 $   question question_subject_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.question
    ADD CONSTRAINT question_subject_id_foreign FOREIGN KEY (subject_id) REFERENCES app.subject(id);
 K   ALTER TABLE ONLY app.question DROP CONSTRAINT question_subject_id_foreign;
       app          postgres    false    210    211    3032                       2606    26194 )   question_z question_z_language_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.question_z
    ADD CONSTRAINT question_z_language_id_foreign FOREIGN KEY (language_id) REFERENCES app.language(id);
 P   ALTER TABLE ONLY app.question_z DROP CONSTRAINT question_z_language_id_foreign;
       app          postgres    false    218    213    3040                       2606    26169 )   question_z question_z_question_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.question_z
    ADD CONSTRAINT question_z_question_id_foreign FOREIGN KEY (question_id) REFERENCES app.question(id);
 P   ALTER TABLE ONLY app.question_z DROP CONSTRAINT question_z_question_id_foreign;
       app          postgres    false    218    211    3034            �           2606    26179    quiz quiz_level_id_foreign    FK CONSTRAINT     u   ALTER TABLE ONLY app.quiz
    ADD CONSTRAINT quiz_level_id_foreign FOREIGN KEY (level_id) REFERENCES app.levels(id);
 A   ALTER TABLE ONLY app.quiz DROP CONSTRAINT quiz_level_id_foreign;
       app          postgres    false    214    212    3036            �           2606    26199 -   quiz_questions quiz_questions_quiz_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.quiz_questions
    ADD CONSTRAINT quiz_questions_quiz_id_foreign FOREIGN KEY (quiz_id) REFERENCES app.quiz(id);
 T   ALTER TABLE ONLY app.quiz_questions DROP CONSTRAINT quiz_questions_quiz_id_foreign;
       app          postgres    false    216    214    3042            �           2606    26144 0   quiz_questions quiz_questions_subject_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.quiz_questions
    ADD CONSTRAINT quiz_questions_subject_id_foreign FOREIGN KEY (subject_id) REFERENCES app.subject(id);
 W   ALTER TABLE ONLY app.quiz_questions DROP CONSTRAINT quiz_questions_subject_id_foreign;
       app          postgres    false    216    210    3032            �           2606    26149    quiz quiz_subject_id_foreign    FK CONSTRAINT     z   ALTER TABLE ONLY app.quiz
    ADD CONSTRAINT quiz_subject_id_foreign FOREIGN KEY (subject_id) REFERENCES app.subject(id);
 C   ALTER TABLE ONLY app.quiz DROP CONSTRAINT quiz_subject_id_foreign;
       app          postgres    false    214    210    3032            �           2606    26139    quiz quiz_user_id_foreign    FK CONSTRAINT     r   ALTER TABLE ONLY app.quiz
    ADD CONSTRAINT quiz_user_id_foreign FOREIGN KEY (user_id) REFERENCES app.users(id);
 @   ALTER TABLE ONLY app.quiz DROP CONSTRAINT quiz_user_id_foreign;
       app          postgres    false    214    209    3030            �           2606    26164 "   subject subject_created_by_foreign    FK CONSTRAINT     ~   ALTER TABLE ONLY app.subject
    ADD CONSTRAINT subject_created_by_foreign FOREIGN KEY (created_by) REFERENCES app.users(id);
 I   ALTER TABLE ONLY app.subject DROP CONSTRAINT subject_created_by_foreign;
       app          postgres    false    210    209    3030            �           2606    26134 "   subject subject_updated_by_foreign    FK CONSTRAINT     ~   ALTER TABLE ONLY app.subject
    ADD CONSTRAINT subject_updated_by_foreign FOREIGN KEY (updated_by) REFERENCES app.users(id);
 I   ALTER TABLE ONLY app.subject DROP CONSTRAINT subject_updated_by_foreign;
       app          postgres    false    3030    210    209                       2606    26154 &   subject_z subject_z_subject_id_foreign    FK CONSTRAINT     �   ALTER TABLE ONLY app.subject_z
    ADD CONSTRAINT subject_z_subject_id_foreign FOREIGN KEY (subject_id) REFERENCES app.subject(id);
 M   ALTER TABLE ONLY app.subject_z DROP CONSTRAINT subject_z_subject_id_foreign;
       app          postgres    false    219    210    3032            �           2606    26184    users users_language_id_foreign    FK CONSTRAINT        ALTER TABLE ONLY app.users
    ADD CONSTRAINT users_language_id_foreign FOREIGN KEY (language_id) REFERENCES app.language(id);
 F   ALTER TABLE ONLY app.users DROP CONSTRAINT users_language_id_foreign;
       app          postgres    false    209    213    3040            �   >   x�%���0���n1��6z�M�/d�7��V�Z�T�>�D�v��5N��2�1>��Y��      �      x������ � �      �      x�3���L�2�
RƜ�~@*F��� C��      �      x�3�LM,��L����� �      �      x�34�4�4�24S1z\\\ r      �   r   x�e�=�0��>Ef�F��8M����K���� ��Oϔ��N��z����z,�u�����^�$H`ȵUo�8�G6�v��߻����l^�����X��2X��)ϙ���       �   5   x�3�4�4�4�4202�50�5�P04�24�26�60���2"���=... �a      �      x������ � �      �   .   x�3�L�4202�50�5�P04�2��21�60���4\1z\\\ ��D      �   7   x�3�4��M,I�M,��N�2r/̹��bӅ����v]��eQ������ m�f      �     x���Mo�@��ï��[#�u��TS4V"����[`ٲ����jMSo�2���}�y�@N�_}�p�h)(�-?���9��o;�Ra蚳��3���J{vh�7ړ��%[P��d�}fּu�h#���5�X�wFhD���1��=#�`�!�L�x{*R.n'@C�����VT��.�.�mg5E�t�4tM}��´�
+^�wĊ&��G�0"�7����F��:���rf��Y3�9�݅-'�\k��=�A�v)��ro~y�O�}�eU?��ʒ$}RՆ�      �   �   x���O�0��O�=�9�G=䡋D�-�UK�Mc����u�����/��;ev�u�C
��1���4
&q�� ��3�2�C*8a|�"ѿ�-�|_�p,�I��vU����P�4����P��E|T9Pp���36b���m��Z���@}BLI���)�{wvb�˜���#�"�>kxi�     