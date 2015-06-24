--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: problem_nearby_match; Type: TYPE; Schema: public; Owner: fms
--

CREATE TYPE problem_nearby_match AS (
	problem_id integer,
	distance double precision
);


ALTER TYPE public.problem_nearby_match OWNER TO fms;

--
-- Name: angle_between(double precision, double precision); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION angle_between(double precision, double precision) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$
select case
    when abs($1 - $2) > pi() then 2 * pi() - abs($1 - $2)
    else abs($1 - $2)
    end;
$_$;


ALTER FUNCTION public.angle_between(double precision, double precision) OWNER TO fms;

--
-- Name: contacts_updated(); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION contacts_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
$$;


ALTER FUNCTION public.contacts_updated() OWNER TO fms;

--
-- Name: ms_current_timestamp(); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION ms_current_timestamp() RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $$
    declare
        today date;
    begin
        today = (select override_today from debugdate);
        if today is not null then
           return today + current_time;
        else
           return current_timestamp;
        end if;
    end;
$$;


ALTER FUNCTION public.ms_current_timestamp() OWNER TO fms;

--
-- Name: problem_find_nearby(double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION problem_find_nearby(double precision, double precision, double precision) RETURNS SETOF problem_nearby_match
    LANGUAGE sql
    AS $_$
    -- trunc due to inaccuracies in floating point arithmetic
    select problem.id,
           R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
            ) as distance
        from problem
        where
            longitude is not null and latitude is not null
            and radians(latitude) > radians($1) - ($3 / R_e())
            and radians(latitude) < radians($1) + ($3 / R_e())
            and (abs(radians($1)) + ($3 / R_e()) > pi() / 2     -- case where search pt is near pole
                    or angle_between(radians(longitude), radians($2))
                            < $3 / (R_e() * cos(radians($1 + $3 / R_e()))))
            -- ugly -- unable to use attribute name "distance" here, sadly
            and R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
                ) < $3
        order by distance desc
$_$;


ALTER FUNCTION public.problem_find_nearby(double precision, double precision, double precision) OWNER TO fms;

--
-- Name: r_e(); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION r_e() RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $$
select 6372.8::double precision;
$$;


ALTER FUNCTION public.r_e() OWNER TO fms;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: abuse; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE abuse (
    email text NOT NULL,
    CONSTRAINT abuse_email_check CHECK ((lower(email) = email))
);


ALTER TABLE public.abuse OWNER TO fms;

--
-- Name: admin_log; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE admin_log (
    id integer NOT NULL,
    admin_user text NOT NULL,
    object_type text NOT NULL,
    object_id integer NOT NULL,
    action text NOT NULL,
    whenedited timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL,
    user_id integer,
    reason text DEFAULT ''::text NOT NULL,
    CONSTRAINT admin_log_object_type_check CHECK ((((object_type = 'problem'::text) OR (object_type = 'update'::text)) OR (object_type = 'user'::text)))
);


ALTER TABLE public.admin_log OWNER TO fms;

--
-- Name: admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.admin_log_id_seq OWNER TO fms;

--
-- Name: admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE admin_log_id_seq OWNED BY admin_log.id;


--
-- Name: alert; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert (
    id integer NOT NULL,
    alert_type text NOT NULL,
    parameter text,
    parameter2 text,
    user_id integer NOT NULL,
    confirmed integer DEFAULT 0 NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    whensubscribed timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL,
    whendisabled timestamp without time zone,
    CONSTRAINT alert_cobrand_check CHECK ((cobrand ~* '^[a-z0-9]*$'::text)),
    CONSTRAINT alert_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9]*$'::text))
);


ALTER TABLE public.alert OWNER TO fms;

--
-- Name: alert_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alert_id_seq OWNER TO fms;

--
-- Name: alert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE alert_id_seq OWNED BY alert.id;


--
-- Name: alert_sent; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert_sent (
    alert_id integer NOT NULL,
    parameter text,
    whenqueued timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL
);


ALTER TABLE public.alert_sent OWNER TO fms;

--
-- Name: alert_type; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert_type (
    ref text NOT NULL,
    head_sql_query text NOT NULL,
    head_table text NOT NULL,
    head_title text NOT NULL,
    head_link text NOT NULL,
    head_description text NOT NULL,
    item_table text NOT NULL,
    item_where text NOT NULL,
    item_order text NOT NULL,
    item_title text NOT NULL,
    item_link text NOT NULL,
    item_description text NOT NULL,
    template text NOT NULL
);


ALTER TABLE public.alert_type OWNER TO fms;

--
-- Name: body; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE body (
    id integer NOT NULL,
    name text NOT NULL,
    parent integer,
    endpoint text,
    jurisdiction text,
    api_key text,
    send_method text,
    send_comments boolean DEFAULT false NOT NULL,
    comment_user_id integer,
    suppress_alerts boolean DEFAULT false NOT NULL,
    can_be_devolved boolean DEFAULT false NOT NULL,
    send_extended_statuses boolean DEFAULT false NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    external_url text
);


ALTER TABLE public.body OWNER TO fms;

--
-- Name: body_areas; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE body_areas (
    body_id integer NOT NULL,
    area_id integer NOT NULL
);


ALTER TABLE public.body_areas OWNER TO fms;

--
-- Name: body_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE body_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.body_id_seq OWNER TO fms;

--
-- Name: body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE body_id_seq OWNED BY body.id;


--
-- Name: comment; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE comment (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    user_id integer NOT NULL,
    anonymous boolean NOT NULL,
    name text,
    website text,
    created timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL,
    confirmed timestamp without time zone,
    text text NOT NULL,
    photo bytea,
    state text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    mark_fixed boolean NOT NULL,
    mark_open boolean DEFAULT false NOT NULL,
    problem_state text,
    external_id text,
    extra text,
    send_fail_count integer DEFAULT 0 NOT NULL,
    send_fail_reason text,
    send_fail_timestamp timestamp without time zone,
    whensent timestamp without time zone,
    CONSTRAINT comment_cobrand_check CHECK ((cobrand ~* '^[a-z0-9]*$'::text)),
    CONSTRAINT comment_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9]*$'::text)),
    CONSTRAINT comment_problem_state_check CHECK ((((((((((((((problem_state = 'confirmed'::text) OR (problem_state = 'investigating'::text)) OR (problem_state = 'planned'::text)) OR (problem_state = 'in progress'::text)) OR (problem_state = 'action scheduled'::text)) OR (problem_state = 'closed'::text)) OR (problem_state = 'fixed'::text)) OR (problem_state = 'fixed - council'::text)) OR (problem_state = 'fixed - user'::text)) OR (problem_state = 'unable to fix'::text)) OR (problem_state = 'not responsible'::text)) OR (problem_state = 'duplicate'::text)) OR (problem_state = 'internal referral'::text))),
    CONSTRAINT comment_state_check CHECK ((((state = 'unconfirmed'::text) OR (state = 'confirmed'::text)) OR (state = 'hidden'::text)))
);


ALTER TABLE public.comment OWNER TO fms;

--
-- Name: comment_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE comment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comment_id_seq OWNER TO fms;

--
-- Name: comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE comment_id_seq OWNED BY comment.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contacts (
    id integer NOT NULL,
    body_id integer NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    email text NOT NULL,
    confirmed boolean NOT NULL,
    deleted boolean NOT NULL,
    editor text NOT NULL,
    whenedited timestamp without time zone NOT NULL,
    note text NOT NULL,
    extra text,
    non_public boolean DEFAULT false,
    endpoint text,
    jurisdiction text DEFAULT ''::text,
    api_key text DEFAULT ''::text,
    send_method text
);


ALTER TABLE public.contacts OWNER TO fms;

--
-- Name: contacts_history; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contacts_history (
    contacts_history_id integer NOT NULL,
    contact_id integer NOT NULL,
    body_id integer NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    email text NOT NULL,
    confirmed boolean NOT NULL,
    deleted boolean NOT NULL,
    editor text NOT NULL,
    whenedited timestamp without time zone NOT NULL,
    note text NOT NULL
);


ALTER TABLE public.contacts_history OWNER TO fms;

--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contacts_history_contacts_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacts_history_contacts_history_id_seq OWNER TO fms;

--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contacts_history_contacts_history_id_seq OWNED BY contacts_history.contacts_history_id;


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacts_id_seq OWNER TO fms;

--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contacts_id_seq OWNED BY contacts.id;


--
-- Name: debugdate; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE debugdate (
    override_today date
);


ALTER TABLE public.debugdate OWNER TO fms;

--
-- Name: flickr_imported; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE flickr_imported (
    id text NOT NULL,
    problem_id integer NOT NULL
);


ALTER TABLE public.flickr_imported OWNER TO fms;

--
-- Name: moderation_original_data; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE moderation_original_data (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    comment_id integer,
    title text,
    detail text,
    photo bytea,
    anonymous boolean NOT NULL,
    created timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL
);


ALTER TABLE public.moderation_original_data OWNER TO fms;

--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE moderation_original_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.moderation_original_data_id_seq OWNER TO fms;

--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE moderation_original_data_id_seq OWNED BY moderation_original_data.id;


--
-- Name: partial_user; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE partial_user (
    id integer NOT NULL,
    service text NOT NULL,
    nsid text NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text NOT NULL
);


ALTER TABLE public.partial_user OWNER TO fms;

--
-- Name: partial_user_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE partial_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partial_user_id_seq OWNER TO fms;

--
-- Name: partial_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE partial_user_id_seq OWNED BY partial_user.id;


--
-- Name: problem; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE problem (
    id integer NOT NULL,
    postcode text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    bodies_str text,
    areas text NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    title text NOT NULL,
    detail text NOT NULL,
    photo bytea,
    used_map boolean NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    anonymous boolean NOT NULL,
    external_id text,
    external_body text,
    external_team text,
    created timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL,
    confirmed timestamp without time zone,
    state text NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    service text DEFAULT ''::text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    lastupdate timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL,
    whensent timestamp without time zone,
    send_questionnaire boolean DEFAULT true NOT NULL,
    extra text,
    flagged boolean DEFAULT false NOT NULL,
    geocode bytea,
    send_fail_count integer DEFAULT 0 NOT NULL,
    send_fail_reason text,
    send_fail_timestamp timestamp without time zone,
    send_method_used text,
    non_public boolean DEFAULT false,
    external_source text,
    external_source_id text,
    interest_count integer DEFAULT 0,
    subcategory text,
    CONSTRAINT problem_cobrand_check CHECK ((cobrand ~* '^[a-z0-9]*$'::text)),
    CONSTRAINT problem_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9]*$'::text)),
    CONSTRAINT problem_state_check CHECK (((((((((((((((((state = 'unconfirmed'::text) OR (state = 'confirmed'::text)) OR (state = 'investigating'::text)) OR (state = 'planned'::text)) OR (state = 'in progress'::text)) OR (state = 'action scheduled'::text)) OR (state = 'closed'::text)) OR (state = 'fixed'::text)) OR (state = 'fixed - council'::text)) OR (state = 'fixed - user'::text)) OR (state = 'hidden'::text)) OR (state = 'partial'::text)) OR (state = 'unable to fix'::text)) OR (state = 'not responsible'::text)) OR (state = 'duplicate'::text)) OR (state = 'internal referral'::text)))
);


ALTER TABLE public.problem OWNER TO fms;

--
-- Name: problem_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE problem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.problem_id_seq OWNER TO fms;

--
-- Name: problem_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE problem_id_seq OWNED BY problem.id;


--
-- Name: questionnaire; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE questionnaire (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    whensent timestamp without time zone NOT NULL,
    whenanswered timestamp without time zone,
    ever_reported boolean,
    old_state text,
    new_state text
);


ALTER TABLE public.questionnaire OWNER TO fms;

--
-- Name: questionnaire_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE questionnaire_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.questionnaire_id_seq OWNER TO fms;

--
-- Name: questionnaire_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE questionnaire_id_seq OWNED BY questionnaire.id;


--
-- Name: secret; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE secret (
    secret text NOT NULL
);


ALTER TABLE public.secret OWNER TO fms;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE sessions (
    id character(72) NOT NULL,
    session_data text,
    expires integer
);


ALTER TABLE public.sessions OWNER TO fms;

--
-- Name: textmystreet; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE textmystreet (
    name text NOT NULL,
    email text NOT NULL,
    postcode text NOT NULL,
    mobile text NOT NULL
);


ALTER TABLE public.textmystreet OWNER TO fms;

--
-- Name: token; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE token (
    scope text NOT NULL,
    token text NOT NULL,
    data bytea NOT NULL,
    created timestamp without time zone DEFAULT ms_current_timestamp() NOT NULL
);


ALTER TABLE public.token OWNER TO fms;

--
-- Name: user_body_permissions; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE user_body_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    body_id integer NOT NULL,
    permission_type text NOT NULL,
    CONSTRAINT user_body_permissions_permission_type_check CHECK (((permission_type = 'moderate'::text) OR (permission_type = 'admin'::text)))
);


ALTER TABLE public.user_body_permissions OWNER TO fms;

--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE user_body_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_body_permissions_id_seq OWNER TO fms;

--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE user_body_permissions_id_seq OWNED BY user_body_permissions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email text NOT NULL,
    name text,
    phone text,
    password text DEFAULT ''::text NOT NULL,
    from_body integer,
    flagged boolean DEFAULT false NOT NULL,
    title text
);


ALTER TABLE public.users OWNER TO fms;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO fms;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY admin_log ALTER COLUMN id SET DEFAULT nextval('admin_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert ALTER COLUMN id SET DEFAULT nextval('alert_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body ALTER COLUMN id SET DEFAULT nextval('body_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment ALTER COLUMN id SET DEFAULT nextval('comment_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts ALTER COLUMN id SET DEFAULT nextval('contacts_id_seq'::regclass);


--
-- Name: contacts_history_id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts_history ALTER COLUMN contacts_history_id SET DEFAULT nextval('contacts_history_contacts_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data ALTER COLUMN id SET DEFAULT nextval('moderation_original_data_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY partial_user ALTER COLUMN id SET DEFAULT nextval('partial_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY problem ALTER COLUMN id SET DEFAULT nextval('problem_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY questionnaire ALTER COLUMN id SET DEFAULT nextval('questionnaire_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions ALTER COLUMN id SET DEFAULT nextval('user_body_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Data for Name: abuse; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY abuse (email) FROM stdin;
\.


--
-- Data for Name: admin_log; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY admin_log (id, admin_user, object_type, object_id, action, whenedited, user_id, reason) FROM stdin;
1	0	problem	10	state_change	2014-03-07 15:54:01.443568	\N	
2	0	problem	10	edit	2014-03-07 15:54:01.486016	\N	
3	Felipe Álvarez	user	8	edit	2014-05-15 17:14:52.491719	\N	
4	Felipe Álvarez	user	9	edit	2014-05-15 17:15:36.947221	\N	
5	Felipe Álvarez	user	6	edit	2014-05-15 17:15:50.709895	\N	
6	0	problem	35	state_change	2014-05-16 14:34:19.944173	\N	
7	0	problem	45	edit	2014-05-16 14:42:08.622203	\N	
8	0	problem	40	edit	2014-05-16 14:42:34.217306	\N	
9	0	problem	34	edit	2014-05-16 14:43:04.943917	\N	
10	0	problem	33	edit	2014-05-16 14:43:09.765413	\N	
11	0	problem	32	edit	2014-05-16 14:43:15.217425	\N	
12	0	problem	31	edit	2014-05-16 14:43:36.783305	\N	
13	0	problem	29	edit	2014-05-16 14:43:41.428455	\N	
14	0	problem	30	edit	2014-05-16 14:44:24.998489	\N	
15	0	problem	34	state_change	2014-05-16 15:19:08.285747	\N	
16	0	problem	33	state_change	2014-05-16 15:19:19.593869	\N	
17	0	problem	1	state_change	2014-05-16 15:42:53.320313	\N	
18	0	problem	2	state_change	2014-05-16 15:43:00.491035	\N	
19	0	problem	3	state_change	2014-05-16 15:43:05.537577	\N	
20	0	problem	4	state_change	2014-05-16 15:43:10.584047	\N	
21	0	problem	6	state_change	2014-05-16 15:43:16.064587	\N	
22	0	problem	7	state_change	2014-05-16 15:43:55.254177	\N	
23	0	problem	10	state_change	2014-05-16 15:44:00.70524	\N	
24	0	problem	11	state_change	2014-05-16 15:44:05.970466	\N	
25	0	problem	12	state_change	2014-05-16 15:44:10.569925	\N	
26	0	problem	13	state_change	2014-05-16 15:44:16.147942	\N	
27	0	problem	14	state_change	2014-05-16 15:44:22.875695	\N	
28	0	problem	16	state_change	2014-05-16 15:44:27.928665	\N	
29	0	problem	26	state_change	2014-05-16 15:46:32.223232	\N	
30	0	problem	25	state_change	2014-05-16 15:46:38.52164	\N	
31	0	problem	24	state_change	2014-05-16 15:46:46.948898	\N	
32	0	problem	23	state_change	2014-05-16 15:46:59.052223	\N	
33	0	problem	22	state_change	2014-05-16 15:47:03.957654	\N	
34	0	problem	21	state_change	2014-05-16 15:47:11.277008	\N	
35	0	problem	19	state_change	2014-05-16 15:47:17.007105	\N	
36	0	problem	18	state_change	2014-05-16 15:47:22.218668	\N	
37	0	problem	27	state_change	2014-05-16 15:48:08.241324	\N	
38	0	problem	28	state_change	2014-05-16 15:48:13.494408	\N	
39	0	problem	29	state_change	2014-05-16 15:48:18.582677	\N	
40	0	problem	30	state_change	2014-05-16 15:48:23.827035	\N	
41	0	problem	31	state_change	2014-05-16 15:48:29.959683	\N	
42	0	problem	32	state_change	2014-05-16 15:48:35.722755	\N	
43	0	problem	36	state_change	2014-05-16 15:48:40.718932	\N	
44	0	problem	37	state_change	2014-05-16 15:49:49.913467	\N	
45	0	problem	38	state_change	2014-05-16 15:49:56.852605	\N	
46	0	problem	39	state_change	2014-05-16 15:50:10.43764	\N	
47	0	problem	40	state_change	2014-05-16 15:50:15.627367	\N	
48	0	problem	44	state_change	2014-05-16 15:50:45.374321	\N	
49	0	problem	45	state_change	2014-05-16 15:50:52.123912	\N	
50	0	problem	46	state_change	2014-05-16 15:50:57.468385	\N	
51	0	problem	17	state_change	2014-05-16 15:51:30.878775	\N	
52	0	problem	20	state_change	2014-05-16 15:51:40.391876	\N	
53	0	problem	14	state_change	2014-05-16 15:52:17.826949	\N	
54	0	problem	27	state_change	2014-05-16 15:53:36.919738	\N	
55	0	problem	11	state_change	2014-05-16 15:54:06.289946	\N	
56	0	problem	8	state_change	2014-05-16 15:54:48.179598	\N	
57	0	problem	43	state_change	2014-05-16 15:56:27.227069	\N	
58	0	problem	42	state_change	2014-05-16 15:56:44.975985	\N	
59	0	problem	15	state_change	2014-05-16 15:59:52.4309	\N	
60	0	problem	47	state_change	2014-05-16 19:56:13.566834	\N	
61	0	problem	48	state_change	2014-05-16 19:56:20.279098	\N	
62	0	problem	58	state_change	2014-05-23 16:41:32.958954	\N	
63	0	problem	57	state_change	2014-05-23 16:41:42.690508	\N	
64	0	problem	56	state_change	2014-05-23 16:41:49.088474	\N	
65	0	problem	50	state_change	2014-05-28 21:52:57.739227	\N	
66	0	problem	52	state_change	2014-05-29 14:24:24.665627	\N	
67	0	problem	14	state_change	2014-05-29 14:25:45.222549	\N	
68	0	problem	41	state_change	2014-05-29 14:27:41.945838	\N	
69	0	problem	53	state_change	2014-05-29 14:28:57.622838	\N	
70	0	problem	51	state_change	2014-05-29 14:30:40.941978	\N	
71	0	problem	49	state_change	2014-05-29 14:32:12.100112	\N	
72	0	problem	8	state_change	2014-05-29 14:36:51.647998	\N	
73	0	problem	11	state_change	2014-05-29 14:38:11.296738	\N	
74	0	problem	42	state_change	2014-08-13 14:07:14.149936	\N	
75	0	problem	41	state_change	2014-08-13 14:08:03.374672	\N	
76	0	problem	103	edit	2015-06-10 16:19:16.704706	\N	
77	0	problem	102	edit	2015-06-10 16:22:31.406565	\N	
\.


--
-- Name: admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('admin_log_id_seq', 77, true);


--
-- Data for Name: alert; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert (id, alert_type, parameter, parameter2, user_id, confirmed, lang, cobrand, cobrand_data, whensubscribed, whendisabled) FROM stdin;
1	new_updates	2	\N	1	1	en-gb	default		2014-03-06 19:43:04.814292	\N
60	new_updates	68	\N	19	1	es-cl	bellavistaenaccion		2014-05-27 16:33:09.005855	\N
2	new_updates	8	\N	3	1	en-gb	default		2014-03-07 13:15:39.04851	\N
3	new_updates	8	\N	4	0	en-gb	default		2014-03-07 13:40:42.133383	\N
4	new_updates	10	\N	6	1	es	default		2014-03-07 19:15:18.800591	\N
61	new_updates	69	\N	10	1	es-cl	bellavistaenaccion		2014-05-29 19:17:00.357394	\N
5	new_updates	11	\N	3	1	es-cl	bellavistaenaccion		2014-03-10 18:35:39.770266	\N
6	new_updates	12	\N	3	1	es-cl	bellavistaenaccion		2014-03-24 19:13:46.715243	\N
62	new_updates	70	\N	10	1	es-cl	bellavistaenaccion		2014-05-29 19:29:28.548375	\N
7	new_updates	13	\N	3	1	es-cl	bellavistaenaccion		2014-03-24 19:49:08.255481	\N
8	new_updates	14	\N	3	1	es-cl	bellavistaenaccion		2014-03-25 14:49:06.484141	\N
63	new_updates	71	\N	10	1	es-cl	bellavistaenaccion		2014-05-29 19:43:29.796434	\N
9	new_updates	15	\N	3	1	es-cl	bellavistaenaccion		2014-03-25 15:24:20.101089	\N
10	new_updates	16	\N	3	1	es-cl	bellavistaenaccion		2014-03-25 18:10:46.118707	\N
64	new_updates	74	\N	10	1	es-cl	bellavistaenaccion		2014-05-29 21:02:23.469175	\N
11	new_updates	17	\N	1	1	es-cl	bellavistaenaccion		2014-04-15 18:06:43.278407	\N
12	new_updates	18	\N	4	1	es-cl	bellavistaenaccion		2014-04-15 18:13:58.611719	\N
65	new_updates	78	\N	20	1	es-cl	bellavistaenaccion		2014-05-30 21:02:41.279006	\N
13	new_updates	10	\N	4	1	es-cl	bellavistaenaccion		2014-04-15 18:38:50.336611	\N
14	new_updates	19	\N	4	1	es-cl	bellavistaenaccion		2014-04-15 18:40:20.187361	\N
66	new_updates	79	\N	8	1	es-cl	bellavistaenaccion		2014-05-31 14:46:04.452736	\N
15	new_updates	20	\N	2	1	es-cl	bellavistaenaccion		2014-04-15 18:43:04.156964	\N
16	new_updates	21	\N	1	1	es-cl	bellavistaenaccion		2014-04-15 19:02:31.447042	\N
67	new_updates	81	\N	3	1	es-cl	bellavistaenaccion		2014-05-31 15:21:55.759599	\N
17	new_updates	23	\N	1	1	en-gb	bellavistaenaccion		2014-04-19 22:29:54.504329	\N
18	new_updates	20	\N	1	1	en-gb	bellavistaenaccion		2014-04-19 22:56:33.964393	\N
68	new_updates	83	\N	23	1	es-cl	bellavistaenaccion		2014-06-01 21:09:44.777605	\N
19	new_updates	25	\N	1	1	es-cl	bellavistaenaccion		2014-04-21 13:09:06.712062	\N
20	new_updates	26	\N	1	1	es-cl	bellavistaenaccion		2014-04-25 12:53:21.836871	\N
69	new_updates	86	\N	26	1	es-cl	bellavistaenaccion		2014-06-03 19:20:40.324057	\N
21	new_updates	16	\N	1	1	es-cl	bellavistaenaccion		2014-04-25 12:53:47.316901	\N
22	new_updates	27	\N	3	1	es-cl	bellavistaenaccion		2014-04-28 14:19:36.932644	\N
70	new_updates	87	\N	3	1	es-cl	bellavistaenaccion		2014-06-04 15:52:36.178826	\N
23	new_updates	33	\N	8	1	es-cl	bellavistaenaccion		2014-05-05 21:12:33.356522	\N
24	new_updates	31	\N	8	1	es-cl	bellavistaenaccion		2014-05-05 21:19:37.945241	\N
71	new_updates	88	\N	27	1	es-cl	bellavistaenaccion		2014-06-09 14:35:58.628966	\N
25	new_updates	30	\N	8	1	es-cl	bellavistaenaccion		2014-05-05 21:25:12.465448	\N
26	new_updates	34	\N	8	1	es-cl	bellavistaenaccion		2014-05-05 21:26:19.202963	\N
72	new_updates	89	\N	27	1	es-cl	bellavistaenaccion		2014-06-09 14:40:49.069124	\N
27	new_updates	35	\N	9	1	es-cl	bellavistaenaccion		2014-05-05 21:31:18.226094	\N
73	new_updates	90	\N	10	1	es-cl	bellavistaenaccion		2014-06-10 22:46:00.050609	\N
28	new_updates	36	\N	3	1	es-cl	bellavistaenaccion		2014-05-07 14:29:01.554666	2014-05-07 14:35:18.730844
29	new_updates	37	\N	1	1	es-cl	bellavistaenaccion		2014-05-07 20:31:54.39163	\N
74	new_updates	91	\N	28	1	es-cl	bellavistaenaccion		2014-06-16 04:37:52.99943	\N
30	new_updates	38	\N	3	1	es-cl	bellavistaenaccion		2014-05-07 21:06:05.848809	\N
31	new_updates	38	\N	1	1	es-cl	bellavistaenaccion		2014-05-07 21:37:52.897588	\N
75	new_updates	92	\N	29	1	es-cl	bellavistaenaccion		2014-06-19 14:32:06.925292	\N
32	new_updates	41	\N	10	1	es-cl	bellavistaenaccion		2014-05-09 13:48:30.424649	\N
33	new_updates	42	\N	10	1	es-cl	bellavistaenaccion		2014-05-09 13:52:06.467562	\N
76	new_updates	90	\N	31	1	es-cl	bellavistaenaccion		2014-07-02 02:35:27.540492	\N
34	new_updates	43	\N	3	1	es-cl	bellavistaenaccion		2014-05-09 15:56:35.65821	\N
77	council_problems	670600	670600	32	1	es-cl	bellavistaenaccion		2014-07-03 19:45:55.925049	\N
35	new_updates	44	\N	3	1	es-cl	bellavistaenaccion		2014-05-09 18:23:25.713271	2014-05-09 18:30:09.872156
78	council_problems	670561	670561	33	1	es-cl	bellavistaenaccion		2014-07-07 19:13:52.712987	\N
36	new_updates	46	\N	3	1	es-cl	bellavistaenaccion		2014-05-14 20:33:09.559672	2014-05-16 14:28:27.433666
37	new_updates	47	\N	9	1	es-cl	bellavistaenaccion		2014-05-16 19:12:34.322738	\N
38	new_updates	48	\N	9	1	es-cl	bellavistaenaccion		2014-05-16 19:47:44.966344	\N
39	new_updates	49	\N	3	1	es-cl	bellavistaenaccion		2014-05-16 22:03:07.3041	\N
40	new_updates	50	\N	3	1	es-cl	bellavistaenaccion		2014-05-16 22:04:51.698797	\N
41	new_updates	51	\N	3	1	es-cl	bellavistaenaccion		2014-05-19 14:36:14.630892	\N
42	new_updates	52	\N	3	1	es-cl	bellavistaenaccion		2014-05-19 15:41:40.3211	\N
43	new_updates	53	\N	3	1	es-cl	bellavistaenaccion		2014-05-20 15:29:01.427534	\N
44	new_updates	54	\N	11	1	es-cl	bellavistaenaccion		2014-05-20 22:02:25.288232	\N
45	new_updates	55	\N	12	1	es-cl	bellavistaenaccion		2014-05-21 00:58:44.622197	\N
46	council_problems	421712	421712	13	1	es-cl	bellavistaenaccion		2014-05-22 18:44:05.72102	\N
47	new_updates	56	\N	14	1	es-cl	bellavistaenaccion		2014-05-23 15:52:34.732889	\N
48	new_updates	56	\N	15	1	es-cl	bellavistaenaccion		2014-05-23 15:58:04.078967	\N
49	new_updates	57	\N	15	1	es-cl	bellavistaenaccion		2014-05-23 16:20:36.024789	\N
50	new_updates	58	\N	15	1	es-cl	bellavistaenaccion		2014-05-23 16:28:45.339398	\N
51	new_updates	59	\N	16	1	es-cl	bellavistaenaccion		2014-05-25 23:11:47.74306	\N
52	new_updates	60	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 14:39:07.046399	\N
53	new_updates	61	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 14:42:48.479521	\N
54	new_updates	62	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 15:00:11.320435	\N
55	new_updates	63	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 15:04:03.787909	\N
56	new_updates	64	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 15:07:12.18565	\N
57	new_updates	65	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 15:47:57.950488	\N
58	new_updates	66	\N	17	1	es-cl	bellavistaenaccion		2014-05-26 15:51:48.483821	\N
59	new_updates	67	\N	18	1	es-cl	bellavistaenaccion		2014-05-27 03:49:03.544596	\N
79	council_problems	670562	670562	36	1	es-cl	bellavistaenaccion		2015-01-15 15:23:07.475046	\N
80	local_problems	-70.611278	-33.429042	36	1	es-cl	bellavistaenaccion		2015-01-15 15:29:48.653028	\N
81	new_updates	95	\N	39	1	es-cl	bellavistaenaccion		2015-06-03 15:40:37.269683	\N
82	new_updates	96	\N	6	1	es-cl	bellavistaenaccion		2015-06-03 21:46:02.229435	\N
83	new_updates	102	\N	9	1	es-cl	barriosenaccion		2015-06-08 21:53:52.947156	\N
84	new_updates	103	\N	9	1	es-cl	barriosenaccion		2015-06-09 13:08:24.737069	\N
\.


--
-- Name: alert_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('alert_id_seq', 84, true);


--
-- Data for Name: alert_sent; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert_sent (alert_id, parameter, whenqueued) FROM stdin;
4	11	2014-04-15 19:02:07.969903
15	12	2014-04-19 23:02:07.183494
10	14	2014-04-25 13:02:07.428845
30	17	2014-05-07 22:02:07.257074
47	24	2014-05-23 16:02:08.479524
79	95	2015-06-03 16:02:07.557507
80	95	2015-06-03 16:02:08.135655
80	96	2015-06-03 22:02:07.168292
80	102	2015-06-08 22:02:07.949869
80	103	2015-06-09 14:02:08.526981
\.


--
-- Data for Name: alert_type; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert_type (ref, head_sql_query, head_table, head_title, head_link, head_description, item_table, item_where, item_order, item_title, item_link, item_description, template) FROM stdin;
new_updates	select * from problem where id=?	problem	Updates on {{title}}	/	Updates on {{title}}	comment	comment.state='confirmed'	created desc	Update by {{name}}	/report/{{problem_id}}#comment_{{id}}	{{text}}	alert-update
new_problems			New problems on FixMyStreet	/	The latest problems reported by users	problem	problem.non_public = 'f' and problem.state in\n        ('confirmed', 'investigating', 'planned', 'in progress',\n         'fixed', 'fixed - council', 'fixed - user', 'closed'\n         'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n         'internal referral' )	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem
new_fixed_problems			Problems recently reported fixed on FixMyStreet	/	The latest problems reported fixed by users	problem	problem.non_public = 'f' and problem.state in ('fixed', 'fixed - user', 'fixed - council')	lastupdate desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem
local_problems			New local problems on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral')	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
local_problems_state			New local problems on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in (?)	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
postcode_local_problems			New problems near {{POSTCODE}} on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral')	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
postcode_local_problems_state			New problems near {{POSTCODE}} on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in (?)	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
council_problems			New problems to {{COUNCIL}} on FixMyStreet	/reports	The latest problems for {{COUNCIL}} reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n      'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    (bodies_str like '%'||?||'%' or bodies_str is null) and\n    areas like '%,'||?||',%'	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-council
ward_problems			New problems for {{COUNCIL}} within {{WARD}} ward on FixMyStreet	/reports	The latest problems for {{COUNCIL}} within {{WARD}} ward reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    (bodies_str like '%'||?||'%' or bodies_str is null) and\n    areas like '%,'||?||',%'	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-ward
area_problems			New problems within {{NAME}}'s boundary on FixMyStreet	/reports	The latest problems within {{NAME}}'s boundary reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    areas like '%,'||?||',%'	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-area
\.


--
-- Data for Name: body; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY body (id, name, parent, endpoint, jurisdiction, api_key, send_method, send_comments, comment_user_id, suppress_alerts, can_be_devolved, send_extended_statuses, deleted, external_url) FROM stdin;
1	Municipalidad de Providencia	\N				Email	f	\N	f	f	f	f	\N
2	Municipalidad de Recoleta	\N				Email	f	\N	f	f	f	f	\N
4		\N					f	\N	f	f	f	f	\N
\.


--
-- Data for Name: body_areas; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY body_areas (body_id, area_id) FROM stdin;
1	718695
2	670562
4	718695
\.


--
-- Name: body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('body_id_seq', 4, true);


--
-- Data for Name: comment; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY comment (id, problem_id, user_id, anonymous, name, website, created, confirmed, text, photo, state, cobrand, lang, cobrand_data, mark_fixed, mark_open, problem_state, external_id, extra, send_fail_count, send_fail_reason, send_fail_timestamp, whensent) FROM stdin;
1	2	2	f	Erika Luque	\N	2014-03-06 19:50:00.171418	\N	Ya se arreglo	\N	unconfirmed	default	en-gb		t	f	fixed - user	\N	\N	0	\N	\N	\N
2	2	1	f	Magdalena Morel	\N	2014-03-06 20:43:59.648139	\N	Ya no está el hoyo, se arregló	\N	unconfirmed	default	en-gb		t	f	fixed - user	\N	\N	0	\N	\N	\N
3	2	4	f	Paula Morel	\N	2014-03-07 13:08:22.291931	\N	Ya lo arreglaron	\N	unconfirmed	default	en-gb		t	f	fixed - user	\N	\N	0	\N	\N	\N
4	10	6	f	Felipe Álvarez	\N	2014-03-07 19:15:18.716711	2014-03-07 19:15:18.716711	A mi me sigue pareciendo feo el bar, pero venden cervezas baratas!!	\N	confirmed	default	es		f	f	fixed	\N	\N	0	\N	\N	\N
5	8	3	f	Erika Luque	\N	2014-03-25 14:56:13.679665	2014-03-25 14:56:13.679665	Colocaron un contenedor de basura	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
6	11	3	f	Erika Luque	\N	2014-03-25 15:29:59.026347	2014-03-25 15:29:59.026347	Material suelto a partir de la ruptura de la acera	\N	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
7	11	3	t	Erika Luque	\N	2014-03-25 15:55:39.520013	2014-03-25 15:55:39.520013	Acera en mal estado	\N	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
8	12	3	f	Erika Luque	\N	2014-03-25 18:14:29.960316	2014-03-25 18:14:29.960316	Colocaron lomo toro antes de la curva	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
9	18	4	t	Magdalena Morel	\N	2014-04-15 18:14:27.808469	2014-04-15 18:14:27.808469	Ya sacaron la basura	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
10	18	4	f	Magdalena Morel	\N	2014-04-15 18:15:33.174727	2014-04-15 18:15:33.174727	Sigue habiendo basura!	\N	confirmed	bellavistaenaccion	es-cl		f	t	confirmed	\N	\N	0	\N	\N	\N
11	10	4	f	Magdalena Morel	\N	2014-04-15 18:38:50.319553	2014-04-15 18:38:50.319553	Jajaja pero sigue siendo feo, mira!	\\x30323266623637323366313438356564653532303533323937353134633332316438313764313632	confirmed	bellavistaenaccion	es-cl		f	f	fixed	\N	\N	0	\N	\N	\N
12	20	1	f	Magdalena Morel Ruiz	\N	2014-04-19 22:56:33.944328	2014-04-19 22:56:33.944328	Arreglado	\\x62623538633338356130313633376366306139623234643863653466393135323862633561663136	confirmed	bellavistaenaccion	en-gb		t	f	fixed - user	\N	\N	0	\N	\N	\N
13	25	1	f	Magdalena Morel	\N	2014-04-21 13:15:53.992542	2014-04-21 13:15:53.992542	Se clausuró ese bar por incumplimiento de normativa	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
14	16	1	f	Magdalena Morel	\N	2014-04-24 19:45:54.537764	2014-04-25 12:53:47.272404	Ya lo arreglaron	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
15	34	8	f	Felipe	\N	2014-05-06 13:54:52.198734	\N	La fiera acaba de entregar un petitorio bastante bien redactado. Aparentemente alguien le ayudó.	\N	unconfirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
16	36	3	t	Erika Luque	\N	2014-05-07 14:35:18.670772	2014-05-07 14:35:18.670772	Agrego foto del problema	\\x62633066383738656466646665346165383565346335323334633130663465623063383833656232	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
17	38	1	f	Magdalena Morel	\N	2014-05-07 21:32:01.215733	2014-05-07 21:37:52.853579	Se arreglo	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
18	44	3	t	Erika Luque	\N	2014-05-09 18:30:09.678151	2014-05-09 18:30:09.678151	Lavado	\N	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
19	34	8	f	Felipe Álvarez	\N	2014-05-09 20:03:36.572027	2014-05-09 20:04:02.37141	La sacamos a pasear y se tranquilizó!	\N	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
20	34	8	f	Felipe Álvarez	\N	2014-05-09 20:04:30.558875	2014-05-09 20:04:30.558875	Todo bien ahora!	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
21	31	8	f	Felipe Álvarez	\N	2014-05-09 20:11:02.410315	2014-05-09 20:11:02.410315	Yaaa po fieeraaa cortalá!	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
22	33	8	f	Felipe Álvarez	\N	2014-05-09 20:12:19.645636	2014-05-09 20:12:19.645636	Awwww que perrita más linda	\\x61323838306231386161363531353633646330383930396232633166653666333530303332323937	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
23	46	3	t	Erika Luque	\N	2014-05-16 14:28:27.382279	2014-05-16 14:28:27.382279	Ya no hay basura en el lugar, fue un problema temporal de unos días	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
24	56	15	f	mario tocol	\N	2014-05-23 15:57:41.586926	2014-05-23 15:58:04.032509	Estimado Javier sabe que en dia las luminarias están apagadas	\N	confirmed	bellavistaenaccion	es-cl		t	f	fixed - user	\N	\N	0	\N	\N	\N
25	67	25	f	Verónica de Dompierre	\N	2014-06-03 15:29:10.038899	\N	Toda la razón la vereda esta en pésimo estado las personas con coches y guaguas tienen muchos problemas para transitar , es muy urgente q arreglen	\N	unconfirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
26	92	29	t	Luis Baeza	\N	2014-06-19 15:22:42.513762	2014-06-19 15:24:02.039525	Para probar que esto no es un hecho aislado subiré una foto cada día que vea repetirse esta situación.	\\x63343361656337653330316538333035346238363734353730363136653466383364353932336633	confirmed	bellavistaenaccion	es-cl		f	f	confirmed	\N	\N	0	\N	\N	\N
27	83	23	f	Mauricio Tapia	\N	2014-06-29 23:35:03.817208	2014-06-29 23:35:03.817208	El problema no tendrá solución mientras no se regule adecuadamente estacionamientos de superficie de Bellavista. Todos vienen a carretear y dejar sus autos en el barrio, en zonas de no pago. Los vecinos casi nunca podemos estacionarnos frente a nuestras casas. Los visitantes nocturnos hacen la "previa" o se toman el último copete en sus autos. Eso genera bulla, desorden, basura y otras consecuencias.	\N	confirmed	bellavistaenaccion	es-cl		f	f	\N	\N	\N	0	\N	\N	\N
28	91	28	f	Víctor Saavedra	\N	2014-08-11 13:15:34.090674	2014-08-11 13:15:34.090674	Lamentablemente el problema persiste. Una lástima que le dé lo mismo al alcalde. La vida de personas peligra en esto.\r\n	\N	confirmed	bellavistaenaccion	es-cl		f	f	\N	\N	\N	0	\N	\N	\N
29	91	28	f	Víctor Saavedra	\N	2015-01-15 23:43:40.675783	2015-01-15 23:43:40.675783	El problema persiste y la alcaldía aún no hace nada (para variar).	\N	confirmed	bellavistaenaccion	es-cl		f	f	\N	\N	\N	0	\N	\N	\N
\.


--
-- Name: comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('comment_id_seq', 29, true);


--
-- Data for Name: contacts; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contacts (id, body_id, category, email, confirmed, deleted, editor, whenedited, note, extra, non_public, endpoint, jurisdiction, api_key, send_method) FROM stdin;
1	1	Pothole	pdaire@ciudadanointeligente.org	f	t	0	2014-03-05 14:22:29.371537		\N	f	\N			\N
2	1	Bache	pdaire@ciudadanointeligente.org	t	t	0	2014-04-24 14:46:26.725126		\N	f	\N			\N
3	2	Farola	pdaire@ciudadanointeligente.org	t	t	0	2014-04-24 14:53:51.248917		\N	f	\N			\N
4	1	Vereda o calle en mal estado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:10.092353	Utilizando el mail de Denise	\N	f	\N			\N
12	2	Basura	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:41.719362	Utilizando el mail de Denise	\N	f	\N			\N
13	2	Estacionamientos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:53.455677	Utilizando el mail de Denise	\N	f	\N			\N
14	2	Luminaria	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:06.334558	Utilizando el mail de Denise	\N	f	\N			\N
11	2	Ruidos molestos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:30.527117	Utilizando el mail de Denise	\N	f	\N			\N
15	2	Sitio o inmueble abandonado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:41.830479	Utilizando el mail de Denise	\N	f	\N			\N
10	2	Vereda o calle en mal estado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:57.179857	Utilizando el mail de Denise	\N	f	\N			\N
16	1	Test	falvarez@votainteligente.cl	t	t	0	2014-05-16 20:00:24.09925	Confirmed	\N	t	\N			\N
6	1	Basura	denise@ciudadviva.cl	t	f	0	2015-06-10 18:20:55.232262	Utilizando el mail de Denise	\N	f	\N			\N
8	1	Luminaria	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:04.10967	Utilizando el mail de Denise	\N	f	\N			\N
7	1	Estacionamientos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:18.167731	Utilizando el mail de Denise	\N	f	\N			\N
5	1	Ruidos molestos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:38.796431	Utilizando el mail de Denise	\N	f	\N			\N
9	1	Sitio o inmueble abandonado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:54.702412	Utilizando el mail de Denise	\N	f	\N			\N
\.


--
-- Data for Name: contacts_history; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contacts_history (contacts_history_id, contact_id, body_id, category, email, confirmed, deleted, editor, whenedited, note) FROM stdin;
1	1	1	Pothole	pdaire@ciudadanointeligente.org	f	f	0	2014-03-05 14:18:24.340082	
2	1	1	Pothole	pdaire@ciudadanointeligente.org	f	t	0	2014-03-05 14:22:29.371537	
3	2	1	Bache	pdaire@ciudadanointeligente.org	t	f	0	2014-03-05 14:22:56.466955	
4	3	2	Farola	pdaire@ciudadanointeligente.org	t	f	0	2014-03-05 14:24:00.50071	
5	4	1	Vereda o calle en mal estado	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:44:30.766069	
6	5	1	Ruidos molestos	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:44:55.91076	
7	6	1	Basura	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:45:14.640019	
8	7	1	Estacionamientos	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:45:29.686785	
9	8	1	Luminaria	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:45:43.404057	
10	9	1	Sitio o inmueble abandonado	comunicaciones@providencia.cl	t	f	0	2014-04-24 14:45:59.475249	
11	2	1	Bache	pdaire@ciudadanointeligente.org	t	t	0	2014-04-24 14:46:26.725126	
12	10	2	Vereda o calle en mal estado	jtobar@recoleta.cl	t	f	0	2014-04-24 14:51:07.870985	
13	11	2	Ruidos molestos	jtobar@recoleta.cl	t	f	0	2014-04-24 14:51:37.24548	
14	12	2	Basura	jtobar@recoleta.cl	t	f	0	2014-04-24 14:51:50.754232	
15	13	2	Estacionamientos	jtobar@recoleta.cl	t	f	0	2014-04-24 14:52:09.274314	
16	14	2	Luminaria	jtobar@recoleta.cl	t	f	0	2014-04-24 14:53:24.328189	
17	15	2	Sitio o inmueble abandonado	jtobar@recoleta.cl	t	f	0	2014-04-24 14:53:40.000136	
18	3	2	Farola	pdaire@ciudadanointeligente.org	t	t	0	2014-04-24 14:53:51.248917	
19	12	2	Basura	almartinez@recoleta.cl	t	f	0	2014-05-16 17:51:27.430258	
20	13	2	Estacionamientos	almartinez@recoleta.cl	t	f	0	2014-05-16 17:51:32.676782	
21	14	2	Luminaria	almartinez@recoleta.cl	t	f	0	2014-05-16 17:51:37.921432	
22	11	2	Ruidos molestos	almartinez@recoleta.cl	t	f	0	2014-05-16 17:51:42.040455	
23	10	2	Vereda o calle en mal estado	almartinez@recoleta.cl	t	f	0	2014-05-16 17:51:46.53177	
24	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 18:23:16.401478	
25	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 18:25:14.120273	Confirmed
26	6	1	Basura	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
27	7	1	Estacionamientos	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
28	8	1	Luminaria	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
29	5	1	Ruidos molestos	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
30	9	1	Sitio o inmueble abandonado	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
31	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
32	4	1	Vereda o calle en mal estado	comunicaciones@providencia.cl	t	f	0	2014-05-16 18:26:39.149241	Confirmed
33	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 18:42:23.341455	Confirmed
34	15	2	Sitio o inmueble abandonado	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:17.846501	
35	12	2	Basura	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
36	13	2	Estacionamientos	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
37	14	2	Luminaria	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
38	11	2	Ruidos molestos	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
39	15	2	Sitio o inmueble abandonado	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
40	10	2	Vereda o calle en mal estado	almartinez@recoleta.cl	t	f	0	2014-05-16 18:44:32.921086	Confirmed
41	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 19:58:47.841932	Confirmed
42	16	1	Test	falvarez@votainteligente.cl	t	f	0	2014-05-16 19:59:44.725211	Confirmed
43	16	1	Test	falvarez@votainteligente.cl	t	t	0	2014-05-16 20:00:24.09925	Confirmed
44	12	2	Basura	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:22:12.808837	Confirmed
45	13	2	Estacionamientos	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:22:27.715219	Confirmed
46	14	2	Luminaria	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:22:34.876482	Confirmed
47	11	2	Ruidos molestos	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:22:56.984286	Confirmed
48	15	2	Sitio o inmueble abandonado	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:23:01.453001	Confirmed
49	10	2	Vereda o calle en mal estado	bellavistaenaccionrecoleta@gmail.com	t	f	0	2014-05-20 15:23:05.946497	Confirmed
50	17	3	Test	informatica@llanquihue.cl	t	f	0	2014-05-23 14:36:01.413389	
51	18	3	test2	ceciliaolivapesoa@gmail.com	t	f	0	2014-05-23 14:38:13.796026	
52	18	3	test2	ceciliaolivapezoa@gmail.com	t	f	0	2014-05-23 16:26:10.526805	
53	17	3	Test	informatica@llanquihue.cl	f	t	0	2014-05-23 16:42:08.01433	
54	18	3	test2	ceciliaolivapezoa@gmail.com	f	t	0	2014-05-23 16:42:18.29679	
55	6	1	Basura	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
56	7	1	Estacionamientos	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
57	8	1	Luminaria	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
58	5	1	Ruidos molestos	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
59	9	1	Sitio o inmueble abandonado	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
60	4	1	Vereda o calle en mal estado	comunicaciones@providencia.cl	t	f	0	2015-01-19 19:28:10.545906	Confirmed
61	6	1	Basura	denise@ciudadviva.cl	t	f	0	2015-06-10 18:20:55.232262	Utilizando el mail de Denise
62	8	1	Luminaria	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:04.10967	Utilizando el mail de Denise
63	7	1	Estacionamientos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:18.167731	Utilizando el mail de Denise
64	5	1	Ruidos molestos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:38.796431	Utilizando el mail de Denise
65	9	1	Sitio o inmueble abandonado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:21:54.702412	Utilizando el mail de Denise
66	4	1	Vereda o calle en mal estado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:10.092353	Utilizando el mail de Denise
67	12	2	Basura	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:41.719362	Utilizando el mail de Denise
68	13	2	Estacionamientos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:22:53.455677	Utilizando el mail de Denise
69	14	2	Luminaria	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:06.334558	Utilizando el mail de Denise
70	11	2	Ruidos molestos	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:30.527117	Utilizando el mail de Denise
71	15	2	Sitio o inmueble abandonado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:41.830479	Utilizando el mail de Denise
72	10	2	Vereda o calle en mal estado	denise@ciudadviva.cl	t	f	0	2015-06-10 18:23:57.179857	Utilizando el mail de Denise
\.


--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contacts_history_contacts_history_id_seq', 72, true);


--
-- Name: contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contacts_id_seq', 18, true);


--
-- Data for Name: debugdate; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY debugdate (override_today) FROM stdin;
\.


--
-- Data for Name: flickr_imported; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY flickr_imported (id, problem_id) FROM stdin;
\.


--
-- Data for Name: moderation_original_data; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY moderation_original_data (id, problem_id, comment_id, title, detail, photo, anonymous, created) FROM stdin;
\.


--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('moderation_original_data_id_seq', 1, false);


--
-- Data for Name: partial_user; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY partial_user (id, service, nsid, name, email, phone) FROM stdin;
\.


--
-- Name: partial_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('partial_user_id_seq', 1, false);


--
-- Data for Name: problem; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY problem (id, postcode, latitude, longitude, bodies_str, areas, category, title, detail, photo, used_map, user_id, name, anonymous, external_id, external_body, external_team, created, confirmed, state, lang, service, cobrand, cobrand_data, lastupdate, whensent, send_questionnaire, extra, flagged, geocode, send_fail_count, send_fail_reason, send_fail_timestamp, send_method_used, non_public, external_source, external_source_id, interest_count, subcategory) FROM stdin;
20		-33.4308847158990119	-70.631024387497277	1	,15294,363208,369480,421712,	Bache	Vereda mala	Vereda en mal estado, con desnivel peligroso	\\x30323266623637323366313438356564653532303533323937353134633332316438313764313632	t	2	Magdalena Morel	f	\N	\N	\N	2014-04-15 18:42:46.267278	2014-04-15 18:43:04.14747	hidden	es-cl		bellavistaenaccion		2014-05-16 15:51:40.387478	2014-04-15 18:45:21.671166	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
5		-33.4300341044381568	-70.638845708984789	2	,15294,363208,369480,421713,	Farola	Cruce cebra en mal estado	La pintura del cruce ya casi no se ve y los autos no se detienen	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-06 20:40:49.00061	\N	unconfirmed	en-gb		default		2014-03-06 20:40:49.00061	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
15	Monitor araucano, providencia	-33.4304816012222972	-70.630225325408702	1	,15294,363208,369480,421712,	Bache	Sitio eriazo	Sitio eriazo sin luz	\N	t	3	Erika Luque	t	\N	\N	\N	2014-03-25 15:24:20.080614	2014-03-25 15:24:20.080614	hidden	es-cl		bellavistaenaccion		2014-05-16 15:59:52.421801	2014-03-25 15:25:21.650336	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
9		-33.4288432343873865	-70.6439955502928427	2	,15294,363208,369480,421713,	Farola	Ruidos molestos	Musica a alto volumen a las 4am	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-07 13:28:56.342625	\N	unconfirmed	en-gb		default		2014-03-07 13:28:56.342625	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
27		-33.4347168409929267	-70.63498332800296	1	,15294,363208,369480,421712,	Sitio o inmueble abandonado	Casa abandonada	Casa abandonada y con cadena	\N	t	3	Erika Luque	t	\N	\N	\N	2014-04-28 14:18:46.466643	2014-04-28 14:19:36.898007	confirmed	es-cl		bellavistaenaccion		2014-05-16 15:53:36.879203	2014-04-28 14:20:21.516035	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
14		-33.4354820000000004	-70.633585999999994	1	,15294,363208,369480,421712,	Bache	Luminaria tapada por follaje	Luminaria tapada por follaje	\N	t	3	Erika Luque	t	\N	\N	\N	2014-03-25 14:48:40.824407	2014-03-25 14:49:06.4766	hidden	es-cl		bellavistaenaccion		2014-05-29 14:25:45.217725	2014-03-25 14:50:22.547125	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
8		-33.4307217362210096	-70.6369129047238573	2	,15294,363208,369480,421713,	Farola	Basura falta de contenedores	No son suficientes los contenedores de basura para el sector, hay cajas y basura en la aceras	\N	t	3	Erika Luque	f	\N	\N	\N	2014-03-07 13:15:39.036989	2014-03-07 13:15:39.036989	hidden	en-gb		default		2014-05-29 14:36:51.61987	2014-03-07 13:20:22.842431	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
11		-33.4287895105412787	-70.6384380132139711	2	,15294,363208,369480,421713,	Farola	Acera en mal estado	Acera en mal estado	\N	t	3	Erika Luque	f	\N	\N	\N	2014-03-10 18:35:39.74947	2014-03-10 18:35:39.74947	hidden	es-cl		bellavistaenaccion		2014-05-29 14:38:11.291206	2014-03-10 18:40:23.385007	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
25		-33.4326153673317918	-70.6305301612848098	1	,15294,363208,369480,421712,	Bache	Ruido	Alto nivel de ruido proveniente de bar a las 4am	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-04-21 13:07:39.253669	2014-04-21 13:09:06.703972	hidden	es-cl		bellavistaenaccion		2014-05-16 15:46:38.482695	2014-04-21 13:10:21.123379	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
3		-33.4246919876425395	-70.6463743968501774	2	,15294,363208,369480,421713,	Farola	Luminaria rota	Una luminaria a mitad de cuadra está rota, el lugar queda muy oscuro de noche	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-06 19:45:32.602599	\N	hidden	en-gb		default		2014-05-16 15:43:05.533013	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
12		-33.4290689034053159	-70.6414963544920482	2	,15294,363208,369480,421713,	Farola	Curva peligrosa	Autos viran en alta velocidad y pueden herir a peatones	\N	t	3	Erika Luque	t	\N	\N	\N	2014-03-24 19:13:46.672667	2014-03-24 19:13:46.672667	hidden	es-cl		bellavistaenaccion		2014-05-16 15:44:10.565276	2014-03-24 19:15:21.837687	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
19		-33.4332305695717764	-70.6376118928377679	2	,15294,363208,369480,421713,	Farola	Falta luz	Muy oscuro, falta poner una luminaria aqui	\\x63626462366239623739633431333365356339343864336239396338363163356438383561386530	t	4	Magdalena Morel	t	\N	\N	\N	2014-04-15 18:40:20.139619	2014-04-15 18:40:20.139619	hidden	es-cl		bellavistaenaccion		2014-05-16 15:47:17.002048	2014-04-15 18:40:22.050579	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
22		-33.4317442726964558	-70.6401653558199882	2	,15294,363208,369480,421713,	Farola	Vereda mala	Muchos hoyos en la acera	\N	t	1	Magdalena Morel Ruiz	f	\N	\N	\N	2014-04-19 22:16:30.830731	\N	hidden	en-gb		bellavistaenaccion		2014-05-16 15:47:03.951865	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
16		-33.4312680000000029	-70.6404160000000019	2	,15294,363208,369480,421713,	Farola	Pavimento en mal estado	Toda la calle en mal estado	\N	t	3	Erika Luque	t	\N	\N	\N	2014-03-25 18:10:36.401812	2014-03-25 18:10:46.08545	hidden	es-cl		bellavistaenaccion		2014-05-16 15:44:27.900267	2014-03-25 18:15:22.08406	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
28		-33.4309384384482584	-70.6310136586609048	1	,15294,363208,369480,421712,	Vereda o calle en mal estado	Vereda en mal estado	Vereda en mal estado	\N	t	3	Erika Luque	t	\N	\N	\N	2014-04-28 15:12:51.874573	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:13.476615	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
18		-33.4298621692966265	-70.6434896812288997	2	,15294,363208,369480,421713,	Farola	Basura en la vereda	Hay basura en la vereda, muchas bolsas que perros han roto	\N	t	4	Magdalena Morel	t	\N	\N	\N	2014-04-15 18:13:23.81379	2014-04-15 18:13:58.604351	hidden	es-cl		bellavistaenaccion		2014-05-16 15:47:22.212209	2014-04-15 18:20:21.369151	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
1	antonia lopez de bello	-33.4320370865144127	-70.6355579437332324	1	,15294,363208,369480,421712,	Bache	Basura	Hay basura en la vereda	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-06 19:09:13.330559	\N	hidden	en-gb		default		2014-05-16 15:42:53.314323	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
2		-33.4316922005985049	-70.6388783095399617	2	,15294,363208,369480,421713,	Farola	Hoyo en la calle	Hay un hoyo en la calzada, en la pista derecha	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-06 19:43:04.799064	2014-03-06 19:43:04.799064	hidden	en-gb		default		2014-05-16 15:43:00.486659	2014-03-06 19:45:21.935712	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
4		-33.4332251112072925	-70.6375982089537615	2	,15294,363208,369480,421713,	Farola	Basura	Hay basura en la vereda norte	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-03-06 20:20:16.451589	\N	hidden	en-gb		default		2014-05-16 15:43:10.577968	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
6		-33.430646970708068	-70.6362469999996989	2	,15294,363208,369480,421713,	Farola	Cruce peligroso	No existe señalética para cruce de peatones, los autos viran en alta velocidad	\N	t	3	Erika Luque	f	\N	\N	\N	2014-03-06 20:43:24.06611	\N	hidden	en-gb		default		2014-05-16 15:43:16.060481	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
7		-33.430646970708068	-70.6362684576715196	2	,15294,363208,369480,421713,	Farola	Cruce peligroso	No existe señalética de cruce peatonal	\N	t	3	Erika Luque	f	\N	\N	\N	2014-03-06 20:49:34.711394	\N	hidden	en-gb		default		2014-05-16 15:43:55.249286	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
10		-33.4314299999999989	-70.6361339999999984	1	,15294,363208,369480,421712,	Bache	Bar feo	Esta es una prueba	\N	t	5	Rodrigo quijada	f	\N	\N	\N	2014-03-07 14:48:43.493434	2014-03-07 15:54:01.388547	hidden	en-gb		default		2014-05-16 15:44:00.67671	2014-03-07 15:55:22.583525	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
13	Antonia López de Bello Bellavista	-33.4313610839028001	-70.6323983015138737	1	,15294,363208,369480,421712,	Bache	Pavimento en mal estado	Pavimento en mal estado en toda la calle	\N	t	3	Erika Luque	t	\N	\N	\N	2014-03-24 19:49:08.244282	2014-03-24 19:49:08.244282	hidden	es-cl		bellavistaenaccion		2014-05-16 15:44:16.108903	2014-03-24 19:50:21.785922	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
26		-33.4331410343357049	-70.6357021600190649	1	,15294,363208,369480,421712,	Basura	Basura	Calle cochina	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-04-24 19:44:40.607825	2014-04-25 12:53:21.797133	hidden	es-cl		bellavistaenaccion		2014-05-16 15:46:32.218024	2014-04-25 12:55:20.610889	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
24		-33.4350452891856236	-70.6354786772468515	1	,15294,363208,369480,421712,	Bache	Calzada en mal estado	Aaaaaaaahhhhhhhhh!!!	\\x62626439656438313463636539653935623435303134636166323036333764386664333130353063	t	7	Jorge heitmann	t	\N	\N	\N	2014-04-19 22:44:39.005144	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:46:46.904646	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
23		-33.4328187067219034	-70.6343288690029709	1	,15294,363208,369480,421712,	Bache	Luminaria mal estado	Luminaria publica tiene el faro roto	\\x61383938616131316139376364656435643235643936356263303837316362623839653136383966	t	1	Magdalena Morel Ruiz	f	\N	\N	\N	2014-04-19 22:29:45.534532	2014-04-19 22:29:54.496499	hidden	en-gb		bellavistaenaccion		2014-05-16 15:46:59.022693	2014-04-19 22:30:28.482401	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
21		-33.4319059999999979	-70.6359719999999953	1	,15294,363208,369480,421712,	Bache	Basura en la vereda	Mucha basura suelta, perros rompieron bolsas acumuladas	\N	t	1	Magdalena Morel	f	\N	\N	\N	2014-04-15 19:01:56.715096	2014-04-15 19:02:31.4377	hidden	es-cl		bellavistaenaccion		2014-05-16 15:47:11.248795	2014-04-15 19:05:20.806121	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
29		-33.4272390000000001	-70.6017420000000016	1	,15294,363208,369480,421712,	Ruidos molestos	La Fiera se arrancó	La Fiera se arrancó y está asustando a los vecinos ayuda por favor!	\N	f	6	Felipe Álvarez	f	\N	\N	\N	2014-04-28 21:17:38.238916	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:18.552973	\N	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
40		-33.4262379999999979	-70.6119529999999997	1	,15294,363208,369480,421712,	Basura	Prueba prueba	Probando probando	\N	t	9	Felipe Alvarez	f	\N	\N	\N	2014-05-08 23:16:17.951525	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:50:15.612171	\N	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
44		-33.4335710000000006	-70.6374299999999948	2	,15294,363208,369480,421713,	Basura	Malos olores	Malos olores	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-09 18:23:25.660876	2014-05-09 18:23:25.660876	hidden	es-cl		bellavistaenaccion		2014-05-16 15:50:45.369643	2014-05-09 18:25:21.550483	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
45		-33.4255860000000027	-70.6032649999999933	1	,15294,363208,369480,421712,	Vereda o calle en mal estado	Asdasd	Asdasdasasdasdas	\N	t	9	Felipe Álvarez	f	\N	\N	\N	2014-05-09 19:35:16.077758	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:50:52.119185	\N	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
46	Antonia López de Bello	-33.4302690000000027	-70.6415499999999952	2	,15294,363208,369480,421713,	Basura	Basura acumulada	Basura acumulada todos los días de 6 a 11 pm	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-14 20:33:09.517073	2014-05-14 20:33:09.517073	hidden	es-cl		bellavistaenaccion		2014-05-16 15:50:57.441109	2014-05-14 20:35:23.170783	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
17		-33.4280552813117211	-70.6401009828036308	2	,15294,363208,369480,421713,	Farola	Sillas obstaculizan paso	Sillas de restaurante obstaculizan paso peatonal frente al cruce	\N	t	1	Magdalena Morel	t	\N	\N	\N	2014-04-15 18:05:29.084582	2014-04-15 18:06:43.234888	hidden	es-cl		bellavistaenaccion		2014-05-16 15:51:30.874345	2014-04-15 18:10:21.957331	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
30	holanda 895, providencia	-33.4270647336376641	-70.6017307116394619	1	,15294,363208,369480,421712,	Estacionamientos	La fiera se escapó	La fiera se escapó y está mordiendo gente	\N	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-05 20:11:00.960286	2014-05-05 21:25:12.446093	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:23.799191	2014-05-05 21:25:21.928754	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
43		-33.4337140000000019	-70.6318720000000013	1	,15294,363208,369480,421712,	Estacionamientos	Taxis mal estacionados	Taxis mal estacionados	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-09 15:56:35.616104	2014-05-09 15:56:35.616104	hidden	es-cl		bellavistaenaccion		2014-05-16 15:56:27.199879	2014-05-09 16:00:22.364131	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
31	holanda 895, providencia	-33.4271005502506924	-70.6017950846558193	1	,15294,363208,369480,421712,	Basura	La fiera se escapó	Sdasd	\\x34663339363566666335323736626235346366623165353661346636653135353638366330666164	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-05 20:13:23.748925	2014-05-05 21:19:37.935057	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:29.953991	2014-05-05 21:20:21.617776	f	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
52		-33.4301863197328331	-70.6417424947205745	2	,507397,508638,515897,549772,	Basura	Acumulación de basura	Acumulación de basura	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-19 15:41:40.306784	2014-05-19 15:41:40.306784	hidden	es-cl		bellavistaenaccion		2014-05-29 14:24:24.63382	2014-05-19 15:45:21.825898	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
47		-33.4290787944778245	-70.5982793423005006	1	,507397,508638,515897,549771,	Test	Probando	Asdasd	\N	t	9	Felipe Alvarez	f	\N	\N	\N	2014-05-16 19:12:23.595608	2014-05-16 19:12:34.286372	hidden	es-cl		bellavistaenaccion		2014-05-16 19:56:13.55963	2014-05-16 19:15:22.286252	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
48	holanda 895, providencia	-33.4251485233089696	-70.6036404444581791	1	,507397,508638,515897,549771,	Test	Test 2	Test 2	\N	t	9	Felipe Alvarez	f	\N	\N	\N	2014-05-16 19:47:16.17582	2014-05-16 19:47:44.936027	hidden	es-cl		bellavistaenaccion		2014-05-16 19:56:20.273484	2014-05-16 19:50:21.614815	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
49		-33.4285746148243561	-70.6406266957699103	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Vereda en mal estado	Vereda en mal estado	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-16 22:03:07.28393	2014-05-16 22:03:07.28393	hidden	es-cl		bellavistaenaccion		2014-05-29 14:32:12.071709	2014-05-16 22:05:20.794874	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
51		-33.4303930000000022	-70.6380869999999987	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Falta de rayado cruce patonal	No hay rayado en el cruce peatonal	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-19 14:36:14.618956	2014-05-19 14:36:14.618956	hidden	es-cl		bellavistaenaccion		2014-05-29 14:30:40.937561	2014-05-19 14:40:21.976621	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
53		-33.4312249999999977	-70.6408409999999947	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Calle en mal estado	El pavimento está en muy mal estado a lo largo de toda la calle	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-20 15:29:01.415837	2014-05-20 15:29:01.415837	hidden	es-cl		bellavistaenaccion		2014-05-29 14:28:57.594329	2014-05-20 15:30:28.447138	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
56		-41.2565480000000022	-73.0054379999999981	3	,507397,509112,517165,554131,	Test	Municipalidad de llanquihue	Sin luz	\N	t	14	javier delgado	f	\N	\N	\N	2014-05-23 15:52:10.974939	2014-05-23 15:52:34.719893	hidden	es-cl		bellavistaenaccion		2014-05-23 16:41:49.058458	2014-05-23 15:55:22.345559	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
50		-33.433103888719792	-70.6348839153445311	1	,507397,508638,515897,549771,	Estacionamientos	Exceso de bicicletas estacionadas en los postes	Falta de cicleteros en esta zona, es común ver muchas bicicletas estacionadas en postes y que dificultan el trásito por la vereda	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-16 22:04:51.687241	2014-05-16 22:04:51.687241	hidden	es-cl		bellavistaenaccion		2014-05-28 21:52:57.729074	2014-05-16 22:05:21.416463	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
35		-33.4255814868580501	-70.6081180741573178	1	,15294,363208,369480,421712,	Estacionamientos	Hay un auto que no me gusta	Los autos son malos	\N	t	9	Felipe Alvarez	f	\N	\N	\N	2014-05-05 21:28:22.901552	2014-05-05 21:31:18.216139	hidden	es-cl		bellavistaenaccion		2014-05-16 14:34:19.912413	2014-05-05 21:35:21.076036	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
32	holanda 895, providencia	-33.4271542751421578	-70.6018809153448785	1	,15294,363208,369480,421712,	Estacionamientos	La fiera se escapó	Asdasd	\N	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-05 20:39:26.172287	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:35.694471	\N	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
42		-33.4346239999999995	-70.6357629999999972	2	,15294,363208,369480,421713,	Sitio o inmueble abandonado	Vandalismo	En Pio Nono, esquina Bellavista, existe un container y un tótem con el mapa del barrio, los cuales están totalmente cubiertos de afiches y grafittis	\N	t	10	Operaciones PB	t	\N	\N	\N	2014-05-09 13:52:06.448504	2014-05-09 13:52:06.448504	confirmed	es-cl		bellavistaenaccion		2014-08-13 14:07:14.118412	2014-05-09 13:55:21.940376	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
34	holanda 895, providencia	-33.4285869266483928	-70.6077710463409858	1	,15294,363208,369480,421712,	Luminaria	La Fiera se tomó una casa	La Fiera está protestando!!! hay que tranquilizarla	\\x37626566376238313834303530626432663535343666613938666262373534653337656366666466	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-05 21:26:19.191162	2014-05-05 21:26:19.191162	unconfirmed	es-cl		bellavistaenaccion		2014-05-16 15:19:08.277566	2014-05-05 21:30:27.944211	f	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
33	holanda 895, providencia	-33.4270826419464129	-70.601838000000356	1	,15294,363208,369480,421712,	Estacionamientos	La Fiera se tomó una casa	La Fiera está protestando!!! hay que tranquilizarla	\\x37626566376238313834303530626432663535343666613938666262373534653337656366666466	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-05 21:04:27.957013	2014-05-05 21:12:33.346918	hidden	es-cl		bellavistaenaccion		2014-05-16 15:19:19.587396	2014-05-05 21:15:21.90783	f	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
36		-33.4323111560021573	-70.6337013240814997	1	,15294,363208,369480,421712,	Basura	Basura	Basura y esocombos de construcción	\N	t	3	Erika Luque	t	\N	\N	\N	2014-05-07 14:29:01.53601	2014-05-07 14:29:01.53601	hidden	es-cl		bellavistaenaccion		2014-05-16 15:48:40.714244	2014-05-07 14:30:30.102601	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
37		-33.43255009946256	-70.6413669854579354	2	,15294,363208,369480,421713,	Luminaria	Luz terrible mala	No se ve na	\\x37396137626630343038323839646437613730626164363861306461373662363737343763616136	t	1	Magdalena Morel	f	\N	\N	\N	2014-05-07 20:30:49.36451	2014-05-07 20:31:54.382119	hidden	es-cl		bellavistaenaccion		2014-05-16 15:49:49.908069	2014-05-07 20:35:21.954485	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
38		-33.4317670000000007	-70.6394889999999975	2	,15294,363208,369480,421713,	Luminaria	Follaje	Mucho follaje	\\x39366364636231623630313265353632393634323839356130646663626539653664636538613438	t	3	Erika Luque	t	\N	\N	\N	2014-05-07 21:06:05.835174	2014-05-07 21:06:05.835174	hidden	es-cl		bellavistaenaccion		2014-05-16 15:49:56.847291	2014-05-07 21:10:22.691139	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
39		-33.4325411458734436	-70.6392319470829051	2	,15294,363208,369480,421713,	Basura	Basura	Mucha basura	\\x39653236376432633033393838646132343234303536383234313462643238373432333761373432	t	1	Magdalena morel	f	\N	\N	\N	2014-05-07 21:31:22.117765	\N	hidden	es-cl		bellavistaenaccion		2014-05-16 15:50:10.400443	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
41		-33.434708595918643	-70.6353758611602842	1	,15294,363208,369480,421712,	Basura	Basura constante en vereda	Todas las mañanas, detecto bolsas de basuras desechas y desparramadas por la vereda norte de Bellavista, casi esquina Pio Nono	\\x66396565613737306135313237326335626361313063313432326134383033306265653564353965	t	10	Operaciones PB	t	\N	\N	\N	2014-05-09 13:48:30.406908	2014-05-09 13:48:30.406908	confirmed	es-cl		bellavistaenaccion		2014-08-13 14:08:03.370112	2014-05-09 13:50:20.86238	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
54	cerrito	-33.4358689999999967	-70.6352579999999932	1	,507397,508638,515897,549771,	Estacionamientos	Automovilistas no respetan el disco "ceda el paso".	En el puente pio nono con santa maría, los automovilistas no respetan el disco "ceda el paso" ni el paso de cebra para el cruce de los peatones ubicado al costado derecho, para doblar hacia sta maría. Es más pasan a altas velocidades y si hay gente cruzando sólo avanzan pasando literalmente por "encima de los peatones". Jamás he visto carabineros fiscalizando ni nada por el estilo. Esto es extremadamente peligroso tanto para los que viivmos en el barrio y que todos los días debemos pasar por allí, como para lxs estudiantes escolares y universitarios.	\N	t	11	Camila Pereda	f	\N	\N	\N	2014-05-20 22:01:07.194583	2014-05-20 22:02:25.278725	confirmed	es-cl		bellavistaenaccion		2014-05-20 22:05:21.749093	2014-05-20 22:05:21.749093	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
55		-33.4348863674022496	-70.6354706306200342	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Cruze Pio Nono oriente Con Santa Maria	Cruze mal señalizado, vehiculos al doblar hacia santa maria hacen caso omiso al disco Pare. Muy peligroso para el peaton que camina por pionono hacia el norte, dado que existen puntos ciegos en donde es imposible visualizar los vehiculos. Una solución a mi parecer seria sincronizar semaro similar a como esta en Carlos Antunes ( vera poniente)con Nva Providencia .- Sldos. Excelente iniciativa.-	\N	t	12	Cristian Quintana Cabrera	t	\N	\N	\N	2014-05-21 00:58:44.610552	2014-05-21 00:58:44.610552	confirmed	es-cl		bellavistaenaccion		2014-05-21 01:00:21.739795	2014-05-21 01:00:21.739795	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
64		-33.4313651302518053	-70.6264071620406781	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Exceso postación	Favor despejar área de circulación de peatones, en especial para sector de rebaje de vereda nor-oriente hacia sur-poniente.	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 15:07:12.170353	2014-05-26 15:07:12.170353	confirmed	es-cl		bellavistaenaccion		2014-06-23 18:16:45.687595	2014-05-26 15:10:21.836275	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
58		-41.2534548837891322	-73.0072530370484145	3	,507397,509112,517165,554131,	test2	Basura en calle	Hay basura en la calle	\N	t	15	marito tocol	f	\N	\N	\N	2014-05-23 16:28:25.128696	2014-05-23 16:28:45.33071	hidden	es-cl		bellavistaenaccion		2014-05-23 16:41:32.930241	2014-05-23 16:30:27.209475	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
57		-41.2505473265563509	-73.0086712434083012	3	,507397,509112,517165,554131,	test2	Luminarias plaza en mal estado	Saben que en l plaza no prenden las luminarias	\N	t	15	mario tocol	f	\N	\N	\N	2014-05-23 16:19:36.379848	2014-05-23 16:20:36.017096	hidden	es-cl		bellavistaenaccion		2014-05-23 16:41:42.684746	2014-05-23 16:25:21.372979	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
61	capellán abarzua	-33.4321309999999983	-70.6298270000000059	1	,507397,508638,515897,549771,	Luminaria	Iluminación peatonal	Nula o débil iluminación peatonal. Favor recorrerla en temporada de invierno después de las 19:00. No se ve nada!	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 14:42:48.467962	2014-05-26 14:42:48.467962	confirmed	es-cl		bellavistaenaccion		2014-05-26 14:45:22.289693	2014-05-26 14:45:22.289693	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
68	Antonia López de bello	-33.4314774820788259	-70.6320978941039357	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Toldos oscuros	El local la picola Italia coloca un toldo fuera de norma. De color café oscuro ( la norma dice blanco o crudo), con unas luces led de colores en el borde, que oscurece la vía peatonal, haciéndola más peligrosa	\N	t	19	Cristian Fernández	t	\N	\N	\N	2014-05-27 16:30:36.545153	2014-05-27 16:33:08.995545	confirmed	es-cl		bellavistaenaccion		2014-05-27 16:35:21.052742	2014-05-27 16:35:21.052742	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
60		-33.431980476430823	-70.6259175832985733	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Resideño cruce	Ante el aumento exponencial de ciclistas por la parte norte del parque en dirección oriente-poniente (y viceversa) y el recorrido en diagonal de peatones hacia y desde la estación de metro, ha echo de este punto un lugar complejo de tránsito. Se solicita un re-diseño y pavimentación de la vereda de acuerdo a los flujos naturales de los ciudadanos.	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 14:39:07.008806	2014-05-26 14:39:07.008806	confirmed	es-cl		bellavistaenaccion		2014-05-26 14:40:21.775246	2014-05-26 14:40:21.775246	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
69		-33.4343489999999974	-70.6357480000000066	2	,507397,508638,515897,549772,	Sitio o inmueble abandonado	Container Abandonado y con grafittis	Se instalo un container el cual lleva mas de 4 meses instalado sobre vereda poniente de calle Pio Nono, entre Bellavista y Dardignac, el cual es rayado y ocupado como baño	\\x38313663353331353033343565316139313634366138616365383464303764643065646233333766	t	10	Operaciones PB	t	\N	\N	\N	2014-05-29 19:17:00.343755	2014-05-29 19:17:00.343755	confirmed	es-cl		bellavistaenaccion		2014-05-29 19:20:21.686303	2014-05-29 19:20:21.686303	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
62		-33.4357705060256905	-70.6352587361070761	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Construir vereda	Favor eliminar estacionamientos vehiculares públicos y construir vereda de calidad para personas a pie. Mejorar accesibilidad universal en este sector!	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 15:00:11.268465	2014-05-26 15:00:11.268465	confirmed	es-cl		bellavistaenaccion		2014-05-26 15:00:22.74619	2014-05-26 15:00:22.74619	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
63		-33.4264478194362127	-70.6238255746981878	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Construcción de vereda!	Se solicita la reducción del número de calzadas vehiculares y construir una vereda para las personas a pie!	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 15:04:03.731748	2014-05-26 15:04:03.731748	confirmed	es-cl		bellavistaenaccion		2014-05-26 15:05:21.342909	2014-05-26 15:05:21.342909	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
65		-33.4328947440974176	-70.6278979510649094	1	,507397,508638,515897,549771,	Estacionamientos	Eliminar estacionamientos en superficie.	Eliminar estacionamientos públicos de superficie frente a Clínica Santa María. No se entiende que ellos existan si la misma Clínica entrega ya este servicio, el cual también es pagado. Mejor recuperar ese espacio ribereño para las personas a pie! Se debiera replicar esto a todo el entorno de la Clínica.	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 15:47:57.909135	2014-05-26 15:47:57.909135	confirmed	es-cl		bellavistaenaccion		2014-05-26 15:50:21.773958	2014-05-26 15:50:21.773958	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
71		-33.4345089999999985	-70.6355120000000056	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Ambulantes	Entre jueves y sábado, de día y con mayor frecuencia de noche, se instalan vendedores ambulantes por calle Pio Nono, entre Costanera Andrés Bello y Dardignac. Carabineros de Chile, hace vista gorda y permite que se generen ventas sin pagar impuestos.	\\x37643466366365643336613966613530623735616135356336346137396230343763643464666231	t	10	Operaciones PB	t	\N	\N	\N	2014-05-29 19:43:29.782203	2014-05-29 19:43:29.782203	confirmed	es-cl		bellavistaenaccion		2014-05-29 19:45:21.867221	2014-05-29 19:45:21.867221	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
66		-33.4320582163258848	-70.6291870438077609	1	,507397,508638,515897,549771,	Estacionamientos	Estacionamientos para bicicletas	Favor equipar frente a la Clínica, Estacionamientos para Bicicletas. Replicar esta solicitud por frente Av. Santa María.	\N	t	17	Mathias Koch	t	\N	\N	\N	2014-05-26 15:51:48.474432	2014-05-26 15:51:48.474432	confirmed	es-cl		bellavistaenaccion		2014-06-25 17:13:19.689981	2014-05-26 15:55:22.472477	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
70		-33.4345399999999984	-70.6355290000000053	1	,507397,508638,515897,549771,	Basura	Basuras	Todas las mañanas se presentan bolsas de basuras de locales comerciales, los cuales no cuentan con contenedores plásticos para su almacenaje y protección a los animales (generalmente perros), los cuales rompen las bolsas dejando todo disperso.	\\x64623363653963643331616238646339613030333061333239336365366562663334346635653133	t	10	Operaciones PB	t	\N	\N	\N	2014-05-29 19:29:28.522056	2014-05-29 19:29:28.522056	confirmed	es-cl		bellavistaenaccion		2014-05-29 19:30:31.085479	2014-05-29 19:30:31.085479	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
59		-33.4311750112885164	-70.6382331865080602	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Vereda inexistente	Frente al Centro Comunitario Juan Verdaguer, se privilegia toda clase de uso del espacio publico en favor del estacionamiento de automoviles, quedando una angosta franja para el uso peatonal, la cual vergonzosamente carece de pavimento y es simplemente un barrial tapado con cholguanes.	\N	t	16	Oscar Cruz	f	\N	\N	\N	2014-05-25 23:11:47.730892	2014-05-25 23:11:47.730892	confirmed	es-cl		bellavistaenaccion		2014-05-25 23:15:21.855839	2014-05-25 23:15:21.855839	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
89		-33.4332201855787687	-70.6441461693118953	2	,507397,508638,515897,549772,	Estacionamientos	Falta de seguridad	El pasaje Banco de Chile es un estacionamiento natural, dado el poco tránsito que tiene. Sin embargo, los estacionadores inescrupulosos, que trabajan sin permiso de la municipalidad, lo utilizan para chantajear a quienes lo utilizan ya que, por ser un lugar más o menos oculto, les ha sido fácil ejercer malas prácticas como "datear" a delincuentes qué autos no han pagado "peaje".\n\nUrge mayor iluminación o la presencia de un parquímetro municipal, para hacerse cargo de la seguridad en el pasaje.	\N	t	27	Fernando Retamales	f	\N	\N	\N	2014-06-09 14:40:49.057439	2014-06-09 14:40:49.057439	confirmed	es-cl		bellavistaenaccion		2014-07-07 16:52:36.019477	2014-06-09 14:45:21.542615	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
72		-33.423853215560662	-70.6040945979001862	1	,507397,508638,515897,549771,	Basura	Esto es una prueba	Prueba prueba prueba	\N	t	8	Felipe Alvarez	f	\N	\N	\N	2014-05-29 20:26:23.814339	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-29 20:26:23.814339	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
73		-33.4244140253990025	-70.6021740343932294	1	,507397,508638,515897,549771,	Estacionamientos	Esto es una prueba	Asdasd	\N	t	6	Felipe Alvarez	f	\N	\N	\N	2014-05-29 20:39:24.169327	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-29 20:39:24.169327	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
79		-33.4296871603163268	-70.6379312023769188	2	,507397,508638,515897,549772,	Estacionamientos	Robos a autos	Constantes rotura de vidrios a autos estacionados con el propósito de robo.	\N	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-31 14:45:23.103515	2014-05-31 14:46:04.443101	confirmed	es-cl		bellavistaenaccion		2014-05-31 14:50:24.74845	2014-05-31 14:50:24.74845	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
75		-33.4252162868510965	-70.6010826931155151	1	,507397,508638,515897,549771,	Basura	Test	Test testtest	\N	t	6	Felipe Alvarez	f	\N	\N	\N	2014-05-29 22:52:07.65533	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-29 22:52:07.65533	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
76		-33.4335479487276857	-70.6375022738185407	2	,507397,508638,515897,549772,	Estacionamientos	Esto es una prueba	Hola esto es una prueba no más	\N	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-30 15:17:09.121242	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-30 15:17:09.121242	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
77		-33.4332380000000029	-70.6381679999999932	2	,507397,508638,515897,549772,	Estacionamientos	Esto es una prueba	Probando probando	\N	t	8	Felipe Álvarez	f	\N	\N	\N	2014-05-30 15:28:39.473015	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-30 15:28:39.473015	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
81		-33.4305459999999997	-70.6391519999999957	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Calle en mal estado	Santa filomena toda la calle en mal estado, intransitable	\N	t	3	Erika Luque	f	\N	\N	\N	2014-05-31 15:21:55.748997	2014-05-31 15:21:55.748997	confirmed	es-cl		bellavistaenaccion		2014-05-31 15:25:21.606888	2014-05-31 15:25:21.606888	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
86		-33.4279919082877015	-70.6397076071324506	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Marcación viraje	Es necesario remarcar pistas y flechas de viraje. Se producen peligrosos cruces. Lo mismo en Bellavista con Loreto.	\N	t	26	Pedro Eva-Condemarín	t	\N	\N	\N	2014-06-03 19:19:19.72067	2014-06-03 19:20:40.316821	confirmed	es-cl		bellavistaenaccion		2014-06-03 19:25:23.020675	2014-06-03 19:25:23.020675	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
80		-33.4297800625815995	-70.6384752751469023	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Rotura vereda	Ver	\\x39303132366564396531666561653166363530343030326533393835323033313139643462323639	t	21	Gino falcone	f	\N	\N	\N	2014-05-31 15:21:08.060702	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-31 15:21:08.060702	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
88		-33.4333785115153646	-70.6430197460331755	2	,507397,508638,515897,549772,	Luminaria	Falta de iluminación	La vereda sur de Bellavista, en el sector entre Loreto y Patronato, no tiene más luminarias que las de los propios edificios lo que sumado a lo árboles altos vuelve la zona muy oscura de noche.	\N	t	27	Fernando Retamales	f	\N	\N	\N	2014-06-09 13:54:14.036024	2014-06-09 14:35:58.62051	confirmed	es-cl		bellavistaenaccion		2014-07-07 16:59:28.160592	2014-06-09 14:40:22.183443	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
82		-33.4318593442359386	-70.6370486269829598	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Hoyo en la calle	Feo	\N	t	22	Sandra vila	f	\N	\N	\N	2014-05-31 15:26:57.245676	\N	unconfirmed	es-cl		bellavistaenaccion		2014-05-31 15:26:57.245676	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
87		-33.4304059999999978	-70.6379019999999969	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Alcantarilla sin tapa	Alcantarilla sin tapa en la esquina de Santa Filomena con Ernesto Pinto Lagarrigue, es muy peligroso para los transeúntes, sobre todo en la noche	\N	t	3	Erika Luque	t	\N	\N	\N	2014-06-04 15:52:36.166849	2014-06-04 15:52:36.166849	confirmed	es-cl		bellavistaenaccion		2014-06-04 15:55:21.904769	2014-06-04 15:55:21.904769	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
84		-33.433246185705265	-70.6386566269834901	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	No respetan paso de cebra	No respetan paso de cebra el cual esta desgastado con el paso de los vehiculos.	\N	t	24	pablo guaita	t	\N	\N	\N	2014-06-01 23:57:03.95142	\N	unconfirmed	es-cl		bellavistaenaccion		2014-06-01 23:57:03.95142	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
85		-33.433246185705265	-70.6386566269834901	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	No respetan paso de cebra	No respetan paso de cebra el cual esta desgastado con el paso de los vehiculos.	\N	t	24	pablo guaita	t	\N	\N	\N	2014-06-01 23:58:04.846546	\N	unconfirmed	es-cl		bellavistaenaccion		2014-06-01 23:58:04.846546	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
90		-33.4340469999999996	-70.6356660000000005	1	,507397,508638,515897,549771,	Luminaria	Alumbrado publico en mal estado	El alumbrado público, por vereda de calle Pio Nono, entre Bellavista y Dardignac, esta en falla en su totalidad. Lo mismo sucede por la vereda de Recoleta.	\\x62333930616533383661653636336634613961353833373436303236633932353836326336373830	t	10	Operaciones PB	t	\N	\N	\N	2014-06-10 22:46:00.036075	2014-06-10 22:46:00.036075	confirmed	es-cl		bellavistaenaccion		2014-06-10 22:50:21.335413	2014-06-10 22:50:21.335413	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
83	crucero exeter	-33.4308364452583007	-70.6322965939160241	1	,507397,508638,515897,549771,	Basura	"Carretes" en la calle Crucero Exeter- Basura y ruidos molestos	La pequeña calle Crucero Exeter se ha convertido todos los fines de semana en refugio para venir a carretear (drogas y alcohol), y en motel informal. Así amanece la calle todos los fines de semana, llena de botellas, latas, vasos, orina, excremento y otros desperdicios que mejor ni les digo. Ello va asociado al ruido, peleas y aumento delincuencia. El problema se debe también a que no hay restricciones para estacionar.	\\x33613534306262663430333164616439363237373836386362636165616462376539353335663162	t	23	Mauricio Tapia	f	\N	\N	\N	2014-06-01 21:08:03.972998	2014-06-01 21:09:44.746644	confirmed	es-cl		bellavistaenaccion		2014-06-29 23:35:03.825542	2014-06-01 21:10:23.925857	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
91		-33.4319903468154394	-70.6383823042302481	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Peligroso paso peatonal	En más de una oportunidad, han ocurrido accidentes entre las calles Purísima y dardiñac. Dado al exceso de velocidad por los conductores, como también por la escasa visualización a distancia del letrero o señalización ubicado en la calle Purísima. Con urgencia se recomienda colocar un lomo de toro en la calle Purísima, de manera que los vehículos estén obligados a detenerse. Esto ayudará mucho a la comunidad.	\N	t	28	Víctor Saavedra	f	\N	\N	\N	2014-06-16 04:37:26.113281	2014-06-16 04:37:52.991648	confirmed	es-cl		bellavistaenaccion		2015-01-15 23:43:40.722361	2014-06-16 04:40:21.428283	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
74		-33.4335009999999997	-70.6347059999999942	1	,507397,508638,515897,549771,	Vereda o calle en mal estado	Arboles con plagas	Muchos arboles del sector, presentan una plaga la cual les afecta su crecimiento y se extiende a las flores y plantas de vecinos.	\N	t	10	Operaciones PB	t	\N	\N	\N	2014-05-29 21:02:23.426583	2014-05-29 21:02:23.426583	confirmed	es-cl		bellavistaenaccion		2014-05-29 21:05:20.986933	2014-05-29 21:05:20.986933	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
78	dardignac 28	-33.4334544185744278	-70.6366071190491169	2	,507397,508638,515897,549772,	Ruidos molestos	Ruidos molestos	Durante las noches de jueves, viernes y sábados, hay batucadas y personas con tambores hasta altas horas de la noche! Y nadie hace nada.	\N	t	20	Carolina Herreros Yrarrazaval	t	\N	\N	\N	2014-05-30 20:59:57.273562	2014-05-30 21:02:41.265539	confirmed	es-cl		bellavistaenaccion		2014-05-30 21:05:22.842026	2014-05-30 21:05:22.842026	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
67		-33.4310115499360592	-70.642025101851786	2	,507397,508638,515897,549772,	Vereda o calle en mal estado	Pavimento en pésimo estado en Loreto entre Santa Filomena y Grsl. Ekchal	Por muchos años la vereda oriente de calle Loreto a la altura del 200 ha estado deteriorada en un grado deplorable, que por razones prácticas, todas las personas que transitan por ella, se ven obligados a caminar por la acera con el potencial peligro que significa el gran flujo de vehículos que circulan por dicha vía. No está demás destacar, que las personas mayores ven menoscabada su integridad física, sobre todo si se trata de personas con sus capacidades físicas disminuídas. A esto se le debe sumar la inveterada costumbre de los conductores de vehículos que se dirigen al oriente por la calle Asunción, viran a la derecha en Loreto, en clara contravención de las normas de tránsito, para dirigirse por General Ekdhal hacia Bombero Núñez.	\N	t	18	Paddy Cortés	f	\N	\N	\N	2014-05-27 03:47:10.397072	2014-05-27 03:49:03.513621	confirmed	es-cl		bellavistaenaccion		2014-06-25 02:37:39.361193	2014-05-27 03:50:22.448245	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
92		-33.4313057506562856	-70.6421419570087039	2	,507397,508638,515897,549772,	Basura	Basura sin contenedor	Todos los dias encontramos cumulos de basura tirada en la acera poniente de la calle Loreto, entre Santa Filomena y Bellavista. Animales comiendo de ahi generan focos de infeccion, por otro lado es desagradable y vergonzoso para los vecinos transitar por Loreto en esas condiciones, nuestro barrio esta sumido en una mala fama de ser peligroso y sucio por el aspecto que le da esta situcion a diario.	\\x37616633666630303938323835343764303966616365623662353261336164346238323664313363	t	29	Luis Baeza	t	\N	\N	\N	2014-06-19 14:29:58.667684	2014-06-19 14:32:06.917776	confirmed	es-cl		bellavistaenaccion		2014-06-19 15:24:02.045779	2014-06-19 14:35:22.489917	f	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
93		-33.4253184474380021	-70.601449745810001	\N	,686843,687884,692902,718695,	Otros	Perrito	Fiera feroz	\N	t	9	felipe alvarez	f	\N	\N	\N	2015-06-02 21:24:00.570425	\N	unconfirmed	es-cl	Android	bellavistaenaccion		2015-06-02 21:24:00.570425	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
94		-33.4332126625322559	-70.6334598332822452	\N	,686843,687884,692902,718695,	Otros	Vereda en mal estado	Hoyos en el pavimento	\N	t	38	Denise Misleh	f	\N	\N	\N	2015-06-03 15:38:05.459331	\N	unconfirmed	es-cl		bellavistaenaccion		2015-06-03 15:38:05.459331	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
95		-33.4263898115019842	-70.6416352063596946	\N	,670562,686843,687884,692902,	Otros	Vereda en mal estado	Hoyos en el pavimento	\N	t	39	Denise Misleh	f	\N	\N	\N	2015-06-03 15:39:10.342783	2015-06-03 15:40:37.260691	confirmed	es-cl		bellavistaenaccion		2015-06-03 15:40:37.260691	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
96		-33.4237359999999981	-70.6070519999999959	\N	,686843,687884,692902,718695,	Otros	Holo	Hoasasd	\N	t	6	Felipe Álvarez	f	\N	\N	\N	2015-06-03 21:46:02.219218	2015-06-03 21:46:02.219218	confirmed	es-cl		bellavistaenaccion		2015-06-03 21:46:02.219218	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
97		-33.425135523000236	-70.6053077196047241	\N	,686843,687884,692902,718695,	Otros	Esto es un reporte de prueba	Asdasd	\N	t	40	Felipe Álvarez	f	\N	\N	\N	2015-06-03 22:08:48.810243	\N	unconfirmed	es-cl		bellavistaenaccion		2015-06-03 22:08:48.810243	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
98		-33.4256034145839607	-70.6070374682925319	\N	,686843,687884,692902,718695,	Otros	Fiera	Sdasdsd	\N	t	6	Felipinwi Alvarez	f	\N	\N	\N	2015-06-04 17:55:17.017833	\N	unconfirmed	es-cl		bellavistaenaccion		2015-06-04 17:55:17.017833	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
99		-33.4251670651783783	-70.6049052434086235	1	,686843,687884,692902,718695,	Basura	Hola hola	Esto es una prueba	\N	t	9	Fundación Ciudadano Inteligente	f	\N	\N	\N	2015-06-04 19:03:22.595353	\N	unconfirmed	es-cl		bellavistaenaccion		2015-06-04 19:03:22.595353	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
100		-33.4235960000000034	-70.6070729999999998	1	,686843,687884,692902,718695,	Basura	Estoy probando	Probando probando probando	\N	t	9	Felipe Álvarez	f	\N	\N	\N	2015-06-05 20:26:09.341663	\N	unconfirmed	es-cl		barriosenaccion		2015-06-05 20:26:09.341663	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
101		-33.4249110000000016	-70.6155849999999958	1	,686843,687884,692902,718695,	Basura	Cámara parchada	Esta s una cámara parchada	\\x30663663616464343335313565386331363161383439323765653162666632386261343731383231	t	9	felipe alvarez	f	\N	\N	\N	2015-06-08 19:54:39.392679	\N	unconfirmed	es-cl	Android	barriosenaccion		2015-06-08 19:54:39.392679	\N	t	\N	f	\N	0	\N	\N	\N	f	\N	\N	0	\N
103		-33.4348979999999969	-70.6180489999999992	1	,686843,687884,692902,718695,	Basura	Perrito fiera	Perrito fiera	\\x30616136313633623238396336666137316633393336616130323632626164623739303063633265	t	9	felipe alvarez	f	\N	\N	\N	2015-06-09 13:07:51.786274	2015-06-09 13:08:24.728797	confirmed	es-cl	Android	barriosenaccion		2015-06-10 16:19:16.69907	2015-06-09 13:10:20.847166	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
102		-33.4365489999999994	-70.6271780000000007	1	,686843,687884,692902,718695,	Ruidos molestos	Hola	Felipe mete mucha bulla	\\x61623461363532616531356538323162393436353866343263383630633362373865383364383032	t	9	felipe alvarez	f	\N	\N	\N	2015-06-08 21:53:38.626713	2015-06-08 21:53:52.938076	confirmed	es-cl	Android	barriosenaccion		2015-06-10 16:22:31.402589	2015-06-08 21:55:21.178318	t	\N	f	\N	0	\N	\N	\N	t	\N	\N	0	\N
\.


--
-- Name: problem_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('problem_id_seq', 103, true);


--
-- Data for Name: questionnaire; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY questionnaire (id, problem_id, whensent, whenanswered, ever_reported, old_state, new_state) FROM stdin;
1	8	2014-03-25 14:56:26.908316	2014-03-25 14:56:26.908316	t	confirmed	fixed - user
2	2	2014-04-03 20:00:21.519319	\N	\N	\N	\N
3	10	2014-04-04 16:00:21.981857	\N	\N	\N	\N
4	11	2014-04-07 19:00:20.198453	\N	\N	\N	\N
5	18	2014-04-15 18:14:49.821807	2014-04-15 18:14:49.821807	f	confirmed	fixed - user
6	25	2014-04-21 13:16:04.912565	2014-04-21 13:16:04.912565	f	confirmed	fixed - user
7	13	2014-04-21 20:00:20.931917	\N	\N	\N	\N
8	14	2014-04-22 15:00:20.468667	\N	\N	\N	\N
9	15	2014-04-22 15:30:28.305942	\N	\N	\N	\N
10	16	2014-04-22 18:30:28.516642	\N	\N	\N	\N
11	34	2014-05-09 20:04:39.256872	2014-05-09 20:04:39.256872	f	confirmed	fixed - user
12	17	2014-05-13 18:30:27.561693	\N	\N	\N	\N
13	20	2014-05-13 19:00:21.748885	\N	\N	\N	\N
14	19	2014-05-13 19:00:22.317143	\N	\N	\N	\N
15	21	2014-05-13 19:30:25.876084	\N	\N	\N	\N
16	27	2014-05-26 14:30:31.178137	\N	\N	\N	\N
17	54	2014-06-17 22:30:28.733205	\N	\N	\N	\N
18	55	2014-06-18 01:30:28.023659	\N	\N	\N	\N
19	59	2014-06-22 23:30:26.242788	\N	\N	\N	\N
20	61	2014-06-23 15:00:20.757974	\N	\N	\N	\N
21	60	2014-06-23 15:00:21.238057	\N	\N	\N	\N
23	63	2014-06-23 15:30:29.270329	\N	\N	\N	\N
24	62	2014-06-23 15:30:29.349992	\N	\N	\N	\N
26	65	2014-06-23 16:00:20.854075	\N	\N	\N	\N
22	64	2014-06-23 15:30:29.089719	2014-06-23 18:16:45.684986	f	confirmed	confirmed
28	68	2014-06-24 17:00:22.026004	\N	\N	\N	\N
27	67	2014-06-24 04:00:20.286753	2014-06-25 02:37:39.358492	f	confirmed	confirmed
25	66	2014-06-23 16:00:20.366157	2014-06-25 17:13:19.648902	\N	confirmed	confirmed
29	69	2014-06-26 19:30:24.794807	\N	\N	\N	\N
30	71	2014-06-26 20:00:21.894992	\N	\N	\N	\N
31	70	2014-06-26 20:00:22.149383	\N	\N	\N	\N
32	74	2014-06-26 21:30:26.917142	\N	\N	\N	\N
33	78	2014-06-27 21:30:27.985415	\N	\N	\N	\N
34	79	2014-06-28 15:00:19.868208	\N	\N	\N	\N
35	81	2014-06-28 15:30:25.462955	\N	\N	\N	\N
36	83	2014-06-29 21:30:28.169577	2014-06-29 23:35:03.81134	t	confirmed	confirmed
37	86	2014-07-01 19:30:27.905349	\N	\N	\N	\N
38	87	2014-07-02 16:00:22.596355	\N	\N	\N	\N
39	89	2014-07-07 15:00:21.702839	2014-07-07 16:52:36.01657	f	confirmed	confirmed
40	88	2014-07-07 15:00:21.997497	2014-07-07 16:59:28.133395	\N	confirmed	confirmed
41	90	2014-07-08 23:00:21.273953	\N	\N	\N	\N
42	91	2014-07-14 05:00:21.831304	2014-07-14 06:32:54.172249	t	confirmed	confirmed
43	92	2014-07-17 15:00:20.916174	\N	\N	\N	\N
44	66	2014-07-23 17:30:27.097084	\N	\N	\N	\N
45	83	2014-07-28 00:00:21.307529	\N	\N	\N	\N
46	88	2014-08-04 17:00:22.643528	\N	\N	\N	\N
47	91	2014-08-11 07:00:21.61091	2014-08-11 13:15:34.085277	\N	confirmed	confirmed
48	42	2014-08-13 14:30:28.518327	\N	\N	\N	\N
49	41	2014-08-13 14:30:28.909865	\N	\N	\N	\N
50	91	2014-09-08 13:30:27.621045	2015-01-15 23:43:40.668604	\N	confirmed	confirmed
\.


--
-- Name: questionnaire_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('questionnaire_id_seq', 50, true);


--
-- Data for Name: secret; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY secret (secret) FROM stdin;
80e89492acc01d9cd71d2b266abc4e9c
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY sessions (id, session_data, expires) FROM stdin;
session:89a3dfaf90782e8eba66ff70e7f5ac08171e2869                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzODQyNjU2MjgAAAAJX19jcmVhdGVkCgoxMzg0\nMjY1NjI4AAAACV9fdXBkYXRlZA==\n	1386684828
session:be2464212496fe0486073eea6b8dc9ff5b87efc9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODE2AAAACV9fdXBkYXRlZA==\n	1396476016
session:2ca91d0f05ba9a540b2bff97cd6cebf6cdeed09e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTM5NTM1NjgAAAAJX19jcmVhdGVkCgoxMzkz\nOTUzNTY5AAAACV9fdXBkYXRlZA==\n	1396372769
session:6eb9a843446686e3268de2b32cdf571affa8bc3e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwMjczOTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDI3MzkwAAAACV9fdXBkYXRlZA==\n	1396446589
session:72bcbe2349805842153469eb18ad523286498159                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MjAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODIwAAAACV9fdXBkYXRlZA==\n	1396476020
session:3bafedd157564b457d80f8e819e39947f5fb4463                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MzUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODM1AAAACV9fdXBkYXRlZA==\n	1396476035
session:0fa36cab693d550e947085ca5764bc37f4b767b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MzYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODM2AAAACV9fdXBkYXRlZA==\n	1396476036
session:d0f30cde26e96b95e15ffd41d7fd15e3f42ea6df                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2ODEAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5NjgxAAAACV9fdXBkYXRlZA==\n	1396468881
session:b059c06afee978da1a75bf9577243670ac3b5a4b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwMzAyNTkAAAAJX19jcmVhdGVkCgoxMzk0\nMDMwMjU5AAAACV9fdXBkYXRlZA==\n	1396449460
session:9edbe148521b63f3a4ed62ade92876cab1aa1e02                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2ODQAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5Njg0AAAACV9fdXBkYXRlZA==\n	1396468884
session:16a7b1b3ac57b728cd326b10aa55ee1cfc5e15ee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2ODUAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5Njg1AAAACV9fdXBkYXRlZA==\n	1396468885
session:ab93442031c81c96b1d73c6d82b3df281ec8ebb0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2ODYAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5Njg2AAAACV9fdXBkYXRlZA==\n	1396468886
session:f5a3b26e16aced772cec77ee470098648aa245d8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5Njk2AAAACV9fdXBkYXRlZA==\n	1396468896
session:f2bde0498445d931cf0f0ab6bb5b94d15d968965                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDk2OTkAAAAJX19jcmVhdGVkCgoxMzk0\nMDQ5Njk5AAAACV9fdXBkYXRlZA==\n	1396468899
session:5f90c036077ba5d6c9a110668ce6c3a3726ac1d0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY3ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2Nzg5AAAACV9fdXBkYXRlZA==\n	1396475989
session:f7e18f8ba7033dedddf9c005f6c6d4e0bb6fb5b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY3OTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2NzkwAAAACV9fdXBkYXRlZA==\n	1396475990
session:3299e986603f4cefde1e48a43723c8b2cb1fc22f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwMjg1MDAAAAAJX19jcmVhdGVkCgoxMzk0\nMDI4NTAwAAAACV9fdXBkYXRlZA==\n	1396450156
session:7797fd45e559acd46325f591909306163f29ccd5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwMzI4ODAAAAAJX19jcmVhdGVkCgoxMzk0\nMDMyODgwAAAACV9fdXBkYXRlZA==\n	1396452080
session:0a7f2c84c927a0a887fb3c66dec60bb177405560                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjA1MzkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwNTM5AAAACV9fdXBkYXRlZA==\n	1398079739
session:16d6a37ac1714986e55fedbd2553ee56fbea5865                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY3OTUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2Nzk2AAAACV9fdXBkYXRlZA==\n	1396475995
session:30ba57a7b84f15c854562bbec52debfc0aa0cbfd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MzYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODM2AAAACV9fdXBkYXRlZA==\n	1396476036
session:497b6ff321c1fbc46eaf6fbcf79b017f0a084f92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY3OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2Nzk2AAAACV9fdXBkYXRlZA==\n	1396475996
session:8e2999cacda400ee321d9fb5bf43225014b16df7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY3OTkAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2Nzk5AAAACV9fdXBkYXRlZA==\n	1396475999
session:7cacbe84a6671a54eecb00b1d37799e7476f7c7f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4MTIAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODEyAAAACV9fdXBkYXRlZA==\n	1396476012
session:8fee0e7860f4cebb071b755c865eb00a49cb1fef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NDMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODQzAAAACV9fdXBkYXRlZA==\n	1396476043
session:a534552d6e4610207c79de0f501b140db5cfacca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODUwAAAACV9fdXBkYXRlZA==\n	1396476050
session:e683c47e9cb61a7b1b6c2bcf37997fdca68ccd2d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NTMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODUzAAAACV9fdXBkYXRlZA==\n	1396476053
session:5c7a50e141365713d63e993a4ad21e58e201354c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NTMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODUzAAAACV9fdXBkYXRlZA==\n	1396476053
session:d1cea13f6e7707fd2558d02b39e219d8b3e9f6af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjQAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY0AAAACV9fdXBkYXRlZA==\n	1396476064
session:629656138b5f54d75ce0cf0ba9c95bff85dbb1a0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY1AAAACV9fdXBkYXRlZA==\n	1396476065
session:d9bfd969a745dae75f788767838aeb7219bd1b01                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY1AAAACV9fdXBkYXRlZA==\n	1396476065
session:a8f97fdd10dca19929cbaab6143f378bbb8deec7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY2AAAACV9fdXBkYXRlZA==\n	1396476066
session:26a09ddfc3416063f37002d44a689dfea97d920d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY2AAAACV9fdXBkYXRlZA==\n	1396476066
session:1ba1bccbf73343661d3fcdcbda689bbf6565eb93                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY2AAAACV9fdXBkYXRlZA==\n	1396476066
session:17fc4b54c51a1da0e2f597c20bdf254b7a5ce11a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4NjgAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODY4AAAACV9fdXBkYXRlZA==\n	1396476068
session:3df48f082406309654bb604bbc0e0a4a60278326                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODgwAAAACV9fdXBkYXRlZA==\n	1396476080
session:16dc7a718ce0c68e74d06dc4033484b3344a1eeb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODgwAAAACV9fdXBkYXRlZA==\n	1396476080
session:b81415c7ceb076c14a0bc1a109e1626544adb070                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODEAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODgxAAAACV9fdXBkYXRlZA==\n	1396476081
session:50233f298b62a80cdb9efc233ef5767c25dd2b2b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODcAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg3AAAACV9fdXBkYXRlZA==\n	1396476087
session:0649383a2fee8220b72f125fe581591056aa7a84                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODgAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg4AAAACV9fdXBkYXRlZA==\n	1396476088
session:d43ec094c657e913a6448667c5362b8d55bb5822                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg5AAAACV9fdXBkYXRlZA==\n	1396476089
session:4d5c37d81018261ad8131f1b1805ff40d3357f2d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg5AAAACV9fdXBkYXRlZA==\n	1396476089
session:593c0b489ddae4460bf2c7584cb3580f857ccf02                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkwAAAACV9fdXBkYXRlZA==\n	1396476090
session:6146bac77aa9631eeb876eeb28138de9d7ea0197                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTEAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkxAAAACV9fdXBkYXRlZA==\n	1396476091
session:8383441e95973d91d0326018de779700901160f5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTEAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkxAAAACV9fdXBkYXRlZA==\n	1396476091
session:5fa1daf18471372958701575e92e3d2f21be9c41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTIAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkyAAAACV9fdXBkYXRlZA==\n	1396476092
session:20eda2aac316e83b182e2ee3c15e4d6a81aa465c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkzAAAACV9fdXBkYXRlZA==\n	1396476093
session:fa954cf12506bbd62076b02cfd6140cc2427a9ee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkzAAAACV9fdXBkYXRlZA==\n	1396476093
session:77d644015855bf5b6b708dcaf02d19993bdbf43d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTQAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk0AAAACV9fdXBkYXRlZA==\n	1396476094
session:c3387d2c04a474551b1b4267e3460156fa617b7a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk1AAAACV9fdXBkYXRlZA==\n	1396476095
session:eafe1ac3667a9f77d81182a0b41b162dbdd789a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk1AAAACV9fdXBkYXRlZA==\n	1396476095
session:99ee68bf67dd9cb742b247ccf433f754511d0a93                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk2AAAACV9fdXBkYXRlZA==\n	1396476096
session:a3b7727ef0b80ad744a560e9d7f925adc96b9109                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTcAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk3AAAACV9fdXBkYXRlZA==\n	1396476097
session:af10b158a2ae09879328a6daa7b5d53f59d99903                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjM2OTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjYzNjkyAAAACV9fdXBkYXRlZA==\n	1398082892
session:f3e572e5f7f9e249f5061a4990dddaa7b2b5519a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NzkzODQAAAAJX19jcmVhdGVkCgoxMzk1\nNjc5Mzg0AAAACV9fdXBkYXRlZA==\n	1398098584
session:545df28fffce85c9c09917550023bc98a8ed4601                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2OTU1OTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjk1NTk5AAAACV9fdXBkYXRlZA==\n	1398114799
session:55dfcff1d390d53b992d6087718d67afffc27db5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3MTM4NjcAAAAJX19jcmVhdGVkCgoxMzk1\nNzEzODY3AAAACV9fdXBkYXRlZA==\n	1398133067
session:7cdc4033812fb957d12d184f1f0042de14888f9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3MzUzNzUAAAAJX19jcmVhdGVkCgoxMzk1\nNzM1Mzc2AAAACV9fdXBkYXRlZA==\n	1398154575
session:2cadf91517386c5f27e41b5dfc9f47a55c1b3929                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQxAAAACV9fdXBkYXRlZA==\n	1398162641
session:5f22ce516c375734ee7a0f512c6b3502b0abbc33                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQxAAAACV9fdXBkYXRlZA==\n	1398162641
session:96f0757cb7392a423c680b7a2548cae432813e94                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQxAAAACV9fdXBkYXRlZA==\n	1398162641
session:83619859dc164e456415a3e7ae6faaac85023c0b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NTM2NDAAAAAJX19jcmVhdGVkCgoxMzk1\nNzUzNjQwAAAACV9fdXBkYXRlZA==\n	1398172840
session:7afb67f6ab147aa563400bc9e611308b0446bfd1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:2af6055c312a91b3ef645252ded3d9d245b4a703                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:5d955297a62f761aa1b8e501977b0d05e5a97486                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:59d223c8839a648769c0f80e64cd782e57cc65cc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:c51b0e1ee55e7206a498bbe704a779c1d8217a07                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:935adc8b1e23645939c1ce0ff386959aedc660dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:0c130ec741b4031eceeea2588c3f59c1978704b5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:511f43bb7bf0e0ab5071b06133e927ae80b1098a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:372bb9bca43c5d0104beb53b06aefcccd2c6c686                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:d629d52f22d66765429b5f4ce531121633503e91                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:87bba118302874af239ddc6f9d94f580f3b4b512                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:2c963b33b1f86e5b8add701cedbadf1a9a88ceb8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:f30f55d256626417c5324ebe9780b10bf5d01006                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODEAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODgxAAAACV9fdXBkYXRlZA==\n	1396476081
session:479f997f4c6a08c26ca7728c01b3835949339a1d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODgAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg4AAAACV9fdXBkYXRlZA==\n	1396476088
session:c066b0e3b82a65b62cd771e2b6facf67b85039ed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODgAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg4AAAACV9fdXBkYXRlZA==\n	1396476088
session:036c32ee9e701c4ccb196aa9f71e1147a2d5f8fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODg5AAAACV9fdXBkYXRlZA==\n	1396476089
session:40398627ecf3c39e9e13340c3d0896a099f556f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkwAAAACV9fdXBkYXRlZA==\n	1396476090
session:0246fc3e9c5853637641dac9c0dd357a2d55b9e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTAAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkwAAAACV9fdXBkYXRlZA==\n	1396476090
session:ab8237566ea1841a61a29e400a8861ca6645463c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTEAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkxAAAACV9fdXBkYXRlZA==\n	1396476091
session:aff7cc45801a47c719b3d27a104a68d13429e831                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTIAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkyAAAACV9fdXBkYXRlZA==\n	1396476092
session:76d34f0c422b4ac235ea60867a687947e3a27b2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTIAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkyAAAACV9fdXBkYXRlZA==\n	1396476092
session:0799a00ade1c2f610c020b949494a09082c7aa79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTMAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODkzAAAACV9fdXBkYXRlZA==\n	1396476093
session:b5814385023a0e2772b59eb27462f740e8ad053e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTQAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk0AAAACV9fdXBkYXRlZA==\n	1396476094
session:3339c221db9f8bc911fa6c80d2e9c89e05e9892e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTQAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk0AAAACV9fdXBkYXRlZA==\n	1396476094
session:2ceab03fd69d9ccb83f38bc13944fac680df704c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTUAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk1AAAACV9fdXBkYXRlZA==\n	1396476095
session:0444a83b677451ba6ee3ba9fc7ec9a63067011a3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk2AAAACV9fdXBkYXRlZA==\n	1396476096
session:8c9416ea37926ca164e6e6223f12d85e606d8c2b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNTY4OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMDU2ODk2AAAACV9fdXBkYXRlZA==\n	1396476096
session:afa3f34abcb0e1e725c4ff4098e968801be4da69                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNjIwMzQAAAAJX19jcmVhdGVkCgoxMzk0\nMDYyMDM0AAAACV9fdXBkYXRlZA==\n	1396481234
session:0e47cc7992b3e840280930fdc81d9146ffd459be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwOTI2NjgAAAAJX19jcmVhdGVkCgoxMzk0\nMDkyNjY4AAAACV9fdXBkYXRlZA==\n	1396511868
session:f051fbecfa842747a0514aa2cf2cc4bc59118db6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwOTg0OTQAAAAJX19jcmVhdGVkCgoxMzk0\nMDk4NDk0AAAACV9fdXBkYXRlZA==\n	1396517694
session:1ac026cbf6208522314396eaf3d016c6aa38dc08                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTE1AAAACV9fdXBkYXRlZA==\n	1396529715
session:79dc864dab8878b61944454b86f4690bfb6ea6ef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQwNDM0MjcAAAAJX19jcmVhdGVkCgoxMzk0\nMDQzNDI4AAAACV9fdXBkYXRlZA==\n	1396524893
session:dc1ab2e1ce8c988517ad2e496e3b41e3de601315                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTEwAAAACV9fdXBkYXRlZA==\n	1396529710
session:0269499947c45a4e2a8cf8e529d9a975a5e3cd00                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTExAAAACV9fdXBkYXRlZA==\n	1396529710
session:a284efd9ac8f38f990f6ab3465426957b15ee2bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTE0AAAACV9fdXBkYXRlZA==\n	1396529714
session:a21010655c5d5bac7ac9e13bd052ca439632f6a5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTE5AAAACV9fdXBkYXRlZA==\n	1396529719
session:c747fe8442557b7cd1078a10195ec68e496ef499                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MTkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTIwAAAACV9fdXBkYXRlZA==\n	1396529719
session:a86061418b527610ae1e5136d056cd105c8ad466                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTIwAAAACV9fdXBkYXRlZA==\n	1396529720
session:65ad166ba87df7d862f362eee6af27ca13473fa7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjEAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTIxAAAACV9fdXBkYXRlZA==\n	1396529720
session:9bc1eca9efe9921af26bd7029962e98cb8208351                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjIAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTIyAAAACV9fdXBkYXRlZA==\n	1396529722
session:6970bf4d3e23da9f54e2dc68eb4d6a1376c29e95                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjMAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTIzAAAACV9fdXBkYXRlZA==\n	1396529723
session:77953660c5a2a5248ec875f30e8521be57fac480                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTI4AAAACV9fdXBkYXRlZA==\n	1396529728
session:3f024f2434757620b539465c415ccb954c5a6b03                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTI4AAAACV9fdXBkYXRlZA==\n	1396529728
session:0cdfc679482a68cb9fe1709c3272aabc0d4cfd8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTI4AAAACV9fdXBkYXRlZA==\n	1396529728
session:b337fe5a3093e39e81702c038b7251b807ea9dfc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MjkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTI5AAAACV9fdXBkYXRlZA==\n	1396529729
session:61754aba726e8b454df3a6aa4e6c04ba87375903                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTMwAAAACV9fdXBkYXRlZA==\n	1396529730
session:16a5a96255ade5e146b64ddcd464181229a7064c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzIAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTMyAAAACV9fdXBkYXRlZA==\n	1396529732
session:bb74db668e272080a26de06a4ce11c77b8cbfd02                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzMAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTMzAAAACV9fdXBkYXRlZA==\n	1396529733
session:b6aa97380ba1b05f0e01bf0c703ddb4784b15e07                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM0AAAACV9fdXBkYXRlZA==\n	1396529734
session:77eeb780949df1c544c498c706114fe2116a6138                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM1AAAACV9fdXBkYXRlZA==\n	1396529735
session:75985033467a6692b8b08a242ca0be1ca24b9f45                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM1AAAACV9fdXBkYXRlZA==\n	1396529735
session:a89896319c71855100a0a63e3abc369002d75f92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM2AAAACV9fdXBkYXRlZA==\n	1396529736
session:f65019cbb03f14109039bfec5e0a0a0e131452e0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDEAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQxAAAACV9fdXBkYXRlZA==\n	1396529741
session:425c226d3cea677b88e257f5c309df19652ffb7e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802189
session:703c4e9e06fab15f194b426c703ef519f11fb883                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Nzk1MTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjc5NTEzAAAACV9fdXBkYXRlZA==\n	1398098713
session:a6ea12b8e00aae7a60591dfe668772f93e6f87e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:f519e71451ccb80191bd32202a388c68a3d3bfcf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2ODIzOTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjgyMzkzAAAACV9fdXBkYXRlZA==\n	1398101593
session:1cce121b94ab8dcebec8d72ec2bb202dc858c1b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:aa54d6f06a574af20a9bdce515f24f76dee4703f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:3fda3c05968ff31af818c1ddfd76547b124ccf5a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3MDc0MTAAAAAJX19jcmVhdGVkCgoxMzk1\nNzA3NDEwAAAACV9fdXBkYXRlZA==\n	1398126610
session:2d9fa9639770f0f4dbf8dafa80da839e329ad403                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3MTk1OTIAAAAJX19jcmVhdGVkCgoxMzk1\nNzE5NTkyAAAACV9fdXBkYXRlZA==\n	1398138792
session:83106cc8ac6a95818f83af51dc929d638ecfed9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3MzY5NTEAAAAJX19jcmVhdGVkCgoxMzk1\nNzM2OTUxAAAACV9fdXBkYXRlZA==\n	1398156151
session:0eee7ccd4a5a491607d278ced1d01722bfb67e05                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQxAAAACV9fdXBkYXRlZA==\n	1398162641
session:19eb7e7220776bc9f80af56a6d826c71a3efbf06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQxAAAACV9fdXBkYXRlZA==\n	1398162641
session:77903df72d7a72e842a4a9456eefae24f61f7b3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NDM0NDIAAAAJX19jcmVhdGVkCgoxMzk1\nNzQzNDQyAAAACV9fdXBkYXRlZA==\n	1398162641
session:6f06350354652ee6db0875425070434204091775                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NTY4NjQAAAAJX19jcmVhdGVkCgoxMzk1\nNzU2ODY0AAAACV9fdXBkYXRlZA==\n	1398176063
session:dcc6279327662de8495c986b00d8e9ac270c43f5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:0e55d0a24982f2780959cf47577d3de301b91598                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:86252c41c45ed53ee5a3a6237a0413da158f3a77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg1AAAACV9fdXBkYXRlZA==\n	1398802185
session:c90f322c3c3d8934680025bd38eee18d79f764ad                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802185
session:1895af6fc8b66ee81dca758f2f2054e326f95223                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:692277ee7c25dd4762d076b20024b9d2b44254c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg2AAAACV9fdXBkYXRlZA==\n	1398802186
session:556ab5c3b6c15873c386b775f79c314b5becec55                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:4676f75230d3012b9a48c1866ef69933f1e5d80f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:9dfb298a81a2e3ba1702847165c16cd6f39fd125                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTE5MDMAAAAJX19jcmVhdGVkCgoxMzk2\nNTkxOTAzAAAACV9fdXBkYXRlZA==\n	1399011103
session:8b4f73ace695adeabea2b633792c1d0e6e9ae135                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTE5MDQAAAAJX19jcmVhdGVkCgoxMzk2\nNTkxOTA0AAAACV9fdXBkYXRlZA==\n	1399011104
session:01112926a8843546d464d3dde62eeb39195395c6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTI2MzMAAAAJX19jcmVhdGVkCgoxMzk2\nNTkyNjMzAAAACV9fdXBkYXRlZA==\n	1399011833
session:e3ddbe73678c10954c8203c67d39a2aa37db784e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTUzNzEAAAAJX19jcmVhdGVkCgoxMzk2\nNTk1MzcxAAAACV9fdXBkYXRlZA==\n	1399014571
session:03a915b7065fa0321ae7a096511a6fab5258c308                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2MTA4MzQAAAAJX19jcmVhdGVkCgoxMzk2\nNjEwODM0AAAACV9fdXBkYXRlZA==\n	1399030034
session:bbc8d10abb1e8c8fc2db823553f36fec893b1a18                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTYAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU2AAAACV9fdXBkYXRlZA==\n	1399066656
session:71f538e73a2214d0dd5b1fdcece11a6753bfd92d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTcAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU3AAAACV9fdXBkYXRlZA==\n	1399066657
session:1bb89657d1c7784ddc8c6f32f6713f69b5f155e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTgAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU4AAAACV9fdXBkYXRlZA==\n	1399066658
session:2158634168603b2269d3cad43492b5089fe092b4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjAAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYwAAAACV9fdXBkYXRlZA==\n	1399066660
session:63ce26ebdd9603869c53242a3a1ec115319c3c8b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjEAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYxAAAACV9fdXBkYXRlZA==\n	1399066661
session:de132d273113864752e56ed4a7075f03ec8e787d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjIAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYyAAAACV9fdXBkYXRlZA==\n	1399066662
session:eb2b41699adb7affa16e361161026fdf97e9e25c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM1AAAACV9fdXBkYXRlZA==\n	1396529735
session:1fbdd8fecf182da748ca39147a4c9ad25971f091                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM2AAAACV9fdXBkYXRlZA==\n	1396529736
session:08f696c091c2547f5089288daa1f315f7cb6eec8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1MzkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTM5AAAACV9fdXBkYXRlZA==\n	1396529739
session:12ad6a310a60f5679942a4488b65f94ef6569a8e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDEAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQxAAAACV9fdXBkYXRlZA==\n	1396529741
session:91160c2c5a1ddbffd871844bc3a84d6e298e806b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDIAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQyAAAACV9fdXBkYXRlZA==\n	1396529742
session:72a2759380b55a4dd78849cb4cc2c348819d69ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ0AAAACV9fdXBkYXRlZA==\n	1396529744
session:7ffde05b1387c62dd4bb51360b41fa9c7c63074f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ0AAAACV9fdXBkYXRlZA==\n	1396529744
session:35c18810ba98e0f1b925355c238cd59c5b03e1a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDcAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ3AAAACV9fdXBkYXRlZA==\n	1396529747
session:53b1c2b3552763910d9887384b0a1edd93b6486a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ4AAAACV9fdXBkYXRlZA==\n	1396529748
session:4336dfa789d6901cdc60ff062dd7fde562644961                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ4AAAACV9fdXBkYXRlZA==\n	1396529748
session:d3e2e56081d7bc96f3bcb38a56f9f782ed23ce13                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ4AAAACV9fdXBkYXRlZA==\n	1396529748
session:b57723283475458ece6906796773f742b5e9e7b5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NDkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTQ5AAAACV9fdXBkYXRlZA==\n	1396529749
session:ae35af7266fef9dc6fd1349aac9695c1a565f069                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTIAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTUyAAAACV9fdXBkYXRlZA==\n	1396529752
session:59daedee059ee11178ef22a0b24f00afd5db76c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU1AAAACV9fdXBkYXRlZA==\n	1396529755
session:5e6f5c2e53777aa3768da9dfd7de0f4a439ef773                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU2AAAACV9fdXBkYXRlZA==\n	1396529756
session:aa4ad462640f9fd0fa068d454a03dbb35b56d80b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU2AAAACV9fdXBkYXRlZA==\n	1396529756
session:845826b82fa3e5cf496fd67b0cfc2fe4a9816052                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU2AAAACV9fdXBkYXRlZA==\n	1396529756
session:26e36f2e6054c43a2fb582c0c520950e9150cf7d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTcAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU3AAAACV9fdXBkYXRlZA==\n	1396529757
session:d18b64f5a762a519dfec034cc6e560c5489f9c1c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NTcAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTU3AAAACV9fdXBkYXRlZA==\n	1396529757
session:ea3d7d3c2cb405160ce200741f777490e9aa97f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTYwAAAACV9fdXBkYXRlZA==\n	1396529760
session:7ce6d2b15ba3e2033ea72323a9d842b2c0f0d0f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjMAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTY0AAAACV9fdXBkYXRlZA==\n	1396529763
session:fb5667bd98384799e19cfbbf06437078050bc024                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTY1AAAACV9fdXBkYXRlZA==\n	1396529765
session:5e34b7fa7e1d419aceef12d08fc2d04e08f70ec2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTY1AAAACV9fdXBkYXRlZA==\n	1396529765
session:517ef467c0a0c021a140a3f320c12d76638fa646                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTY2AAAACV9fdXBkYXRlZA==\n	1396529766
session:09045a19e64c138bbe7a568838c56e8f48b669a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NjcAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTY3AAAACV9fdXBkYXRlZA==\n	1396529767
session:35146c50fc19fe4d83e3045c3af4c6556bae499c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTcwAAAACV9fdXBkYXRlZA==\n	1396529770
session:cee3dd1bab2316aa712132edde1dabfa7e1b85f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzIAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTcyAAAACV9fdXBkYXRlZA==\n	1396529772
session:3cb1333ed225c438fccbd9b0649a6afc1c3fa90d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzMAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTczAAAACV9fdXBkYXRlZA==\n	1396529773
session:1543d88f40c5c14edc23fa66644caab3042e12a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc0AAAACV9fdXBkYXRlZA==\n	1396529774
session:5ac5a2769b94c92cf355b0718a5ee790044e7fd9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc0AAAACV9fdXBkYXRlZA==\n	1396529774
session:0d509f2d82725a186a81e861f2946e45813de554                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc0AAAACV9fdXBkYXRlZA==\n	1396529774
session:1f5304c4ac0df9719492c8a5c283c418e7415758                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzUAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc1AAAACV9fdXBkYXRlZA==\n	1396529775
session:d43c918b6c223e5d2f74a0aa8d00c262a901f6bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc4AAAACV9fdXBkYXRlZA==\n	1396529778
session:2ba0e11d4f1dd69003b38773964c818a52d101a0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc4AAAACV9fdXBkYXRlZA==\n	1396529778
session:cdde8ce04d2732071b970a289e71ac99966c456a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc5AAAACV9fdXBkYXRlZA==\n	1396529779
session:ce4fee53ee5f1cfe8429d0e49c48d4557752858e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc5AAAACV9fdXBkYXRlZA==\n	1396529779
session:a6d1b634896bacccfe2fa8f7460d93b534fd9054                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1NzkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTc5AAAACV9fdXBkYXRlZA==\n	1396529779
session:2e177bbb8402bbf80e3bb7cb4ec98e111cb6800a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODAAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTgwAAAACV9fdXBkYXRlZA==\n	1396529780
session:e07e6628c3fd0fbf1f7b88f7faa621babf073e56                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODQAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTg0AAAACV9fdXBkYXRlZA==\n	1396529784
session:8cda1e8ae00805a9a7cbe882369d40339e94d501                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTg5AAAACV9fdXBkYXRlZA==\n	1396529789
session:76c4a740f9852206cc231296809addbdee2a0944                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1OTMAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTkzAAAACV9fdXBkYXRlZA==\n	1396529793
session:2ea43acd2c9fd739e4fceac4e49e078dcaf5a830                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NjgxMTUAAAAJX19jcmVhdGVkCgoxMzk2\nNjY4MTE1AAAACV9fdXBkYXRlZA==\n	1399087314
session:14d874120690eeaa8901e49c8d9063a5dc223a88                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODAAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgwAAAACV9fdXBkYXRlZA==\n	1399202280
session:d84bf503dce4525176bf74ff0c3d05b160babb54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODEAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgxAAAACV9fdXBkYXRlZA==\n	1399202281
session:ce389500a3b0423d8e00eda86c3188c9b6c3da5b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODEAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgxAAAACV9fdXBkYXRlZA==\n	1399202281
session:64a7412d915d2369646781cd1796ebe4eaff43a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODIAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgyAAAACV9fdXBkYXRlZA==\n	1399202282
session:49b5139e73ba0e6b69f7e08ae46215d253893a76                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiDAAAAAmlkAAAABl9fdXNlcgoKMTM5NTc3MjExMQAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk1NzcyMTExAAAACV9fdXBkYXRlZA==\n	1398191671
session:b46b1d5d58341303789d4bc92d6615cfe2f0856b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4MTU2MDMAAAAJX19jcmVhdGVkCgoxMzk2\nODE1NjAzAAAACV9fdXBkYXRlZA==\n	1399234803
session:12dfcb6049699962fafb01eec8282c7619a756ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4MTU2MDQAAAAJX19jcmVhdGVkCgoxMzk2\nODE1NjA0AAAACV9fdXBkYXRlZA==\n	1399234804
session:50ebe0b58b81d4de791ef12fbe6c53935e4899e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NTg2NDYAAAAJX19jcmVhdGVkCgoxMzk1\nNzU4NjQ2AAAACV9fdXBkYXRlZA==\n	1398194382
session:64f4d91b289e4a3260053a71c1f7416afec7b708                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802189
session:b2075377e8fc9408cbdde8b5a27c2761716334af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:0aa5dc68dd886af283b4d0d07afd44d35b79ea66                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:8385ca98d6cef795ffde4d24d7a778dd077fd585                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:1f26a450b7d7d462e28201a76b8657eac397e478                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:10cb30ea7ab917f8a18b7ef1d7bb939e6047f73c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5OTAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTkwAAAACV9fdXBkYXRlZA==\n	1398802190
session:6a3f321cec7844dc16d522e2838617c3f6eac582                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3NjMyMDMAAAAJX19jcmVhdGVkCgoxMzk1\nNzYzMjAzAAAACV9fdXBkYXRlZA==\n	1398191262
session:3f551905914c126aed52785e844278727de34511                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4Mzk5MTgAAAAJX19jcmVhdGVkCgoxMzk2\nODM5OTE4AAAACV9fdXBkYXRlZA==\n	1399259118
session:27ba1a7132aee068adeb0150f8220b8b924d86f9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4Mzk5MTkAAAAJX19jcmVhdGVkCgoxMzk2\nODM5OTE5AAAACV9fdXBkYXRlZA==\n	1399259119
session:e1b5671197cb241c7f325053dcf496bd7990912b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4Mzk5MTkAAAAJX19jcmVhdGVkCgoxMzk2\nODM5OTIwAAAACV9fdXBkYXRlZA==\n	1399259119
session:101c7285c46f3bceca171f387ee9230a377075ed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4Mzk5MjAAAAAJX19jcmVhdGVkCgoxMzk2\nODM5OTIwAAAACV9fdXBkYXRlZA==\n	1399259120
session:f39f23add69f336d7a516a1e89352ad63274bb4f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4Mzk5MjEAAAAJX19jcmVhdGVkCgoxMzk2\nODM5OTIxAAAACV9fdXBkYXRlZA==\n	1399259121
session:5ce61186d9b0c38c21ed81c5f0f384486c5e7bfb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4NjUyNTkAAAAJX19jcmVhdGVkCgoxMzk2\nODY1MjU5AAAACV9fdXBkYXRlZA==\n	1399284459
session:ae2782fc0c77226bb70294ed4f930f53367561e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4ODk4NDgAAAAJX19jcmVhdGVkCgoxMzk2\nODg5ODQ5AAAACV9fdXBkYXRlZA==\n	1399309048
session:4dae051a8130abfbb70289ec1f1e5c48b32adc22                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY4OTI0OTkAAAAJX19jcmVhdGVkCgoxMzk2\nODkyNDk5AAAACV9fdXBkYXRlZA==\n	1399311699
session:6e12fa17efd1f30b2e7cf0ad014162fba88b5207                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY5MDc0ODAAAAAJX19jcmVhdGVkCgoxMzk2\nOTA3NDgwAAAACV9fdXBkYXRlZA==\n	1399326680
session:80dec6cd4a93a3f0f26683099aa872a08926a1e4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY5MTEwODcAAAAJX19jcmVhdGVkCgoxMzk2\nOTExMDg3AAAACV9fdXBkYXRlZA==\n	1399330287
session:890d7ac8f8e1e5640dc7eb648314442111767b35                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY5NDMzMjQAAAAJX19jcmVhdGVkCgoxMzk2\nOTQzMzI0AAAACV9fdXBkYXRlZA==\n	1399362524
session:f675ce09cdcff4b869356f5a3e4047f364e6be58                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY5NTgxNzAAAAAJX19jcmVhdGVkCgoxMzk2\nOTU4MTcwAAAACV9fdXBkYXRlZA==\n	1399377370
session:3b9376cbf811c3631e2fd0d88836397e144e9237                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMTU1MzUAAAAJX19jcmVhdGVkCgoxMzk3\nMDE1NTM1AAAACV9fdXBkYXRlZA==\n	1399434735
session:869529afda7e57da54ef8d7b3fd8e78fd82f7fe4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzQAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc0AAAACV9fdXBkYXRlZA==\n	1399448974
session:f9537d90b4129c14b205c49bb2926cc990537dc1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzQAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc0AAAACV9fdXBkYXRlZA==\n	1399448974
session:7faf3c0f626a9c737792acfa74648d77b98102e0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODEAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTgxAAAACV9fdXBkYXRlZA==\n	1396529781
session:87131dc093d3ecd801fa4886d0d5e9bd61c00761                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODgAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTg4AAAACV9fdXBkYXRlZA==\n	1396529788
session:a5715fb0831fb7ba9cb8f77682f37550350c561e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1ODkAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTg5AAAACV9fdXBkYXRlZA==\n	1396529789
session:40319146a3a219dac677461277238ea3c6384f70                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTA1OTYAAAAJX19jcmVhdGVkCgoxMzk0\nMTEwNTk2AAAACV9fdXBkYXRlZA==\n	1396529796
session:1b1126e420a98cb3acb08c1baad136ee991a818a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxNTAxMzEAAAAJX19jcmVhdGVkCgoxMzk0\nMTUwMTMxAAAACV9fdXBkYXRlZA==\n	1396569331
session:db46e0fa84b1205d5f992bfdf03df7358f391361                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTQxODcAAAAJX19jcmVhdGVkCgoxMzk0\nMTE0MTg3AAAACV9fdXBkYXRlZA==\n	1396533388
session:d059e2f73be0110724691d697001454eef2db25f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxODkwMjYAAAAJX19jcmVhdGVkCgoxMzk0\nMTg5MDI2AAAACV9fdXBkYXRlZA==\n	1396608225
session:ee4a757daf9351157bb2f4489d2e7b7d0fb0c6de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjE5OTcAAAAJX19jcmVhdGVkCgoxMzk0\nMTIxOTk3AAAACV9fdXBkYXRlZA==\n	1398866511
session:4a1f0b5b90d4ddc1b0826223504e8b7d558733fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDQ2ODYAAAAJX19jcmVhdGVkCgoxMzk0\nMjA0Njg2AAAACV9fdXBkYXRlZA==\n	1396623920
session:dfdd50d5281443d5b4631bb1d82a6742613575a5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTYwNzAAAAAJX19jcmVhdGVkCgoxMzk0\nMTE2MDcwAAAACV9fdXBkYXRlZA==\n	1396541024
session:fa7c7aad70e93401c266b1a9dd0edc1cab19b86f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDA3ODMAAAAJX19jcmVhdGVkCgoxMzk0\nMjAwNzgzAAAACV9fdXBkYXRlZA==\n	1396620040
session:2997595fa7bb1247b9bef9a927fbb148b37be794                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTM0MzAAAAAJX19jcmVhdGVkCgoxMzk0\nNDkzNDMwAAAACV9fdXBkYXRlZA==\n	1396912630
session:1d2b8584ce39b984ae2759ab51fb1b86294f7857                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjIxMzEAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyMTMxAAAACV9fdXBkYXRlZA==\n	1396541331
session:82f8ffc1aed324fc94d351020ab96670519cc827                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjIxMzIAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyMTMyAAAACV9fdXBkYXRlZA==\n	1396541332
session:c5ba9a6786c1e752689ec5cdcaa16ee02f7b812d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMTQyNDEAAAAJX19jcmVhdGVkCgoxMzk0\nMTE0MjQxAAAACV9fdXBkYXRlZA==\n	1396533622
session:3631be408c58b0ebacbe8fc898d99db7369ca08c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjIxMzIAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyMTMyAAAACV9fdXBkYXRlZA==\n	1396541332
session:5006ab7290b29530fdd9fe18b3aeb17cd0b22a85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjIxMzMAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyMTMzAAAACV9fdXBkYXRlZA==\n	1396541333
session:32b74b61dad57b197a1a3456ee8c9a397c6922a5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjIxMzMAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyMTMzAAAACV9fdXBkYXRlZA==\n	1396541333
session:99941535c0b6222d4a9d2c4afe8582d00af1ad9c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjI5MDcAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyOTA3AAAACV9fdXBkYXRlZA==\n	1396542107
session:a3d69650d099c2f61b75bff7171ae9354b4de01e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjI5MjAAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyOTIwAAAACV9fdXBkYXRlZA==\n	1396542120
session:70a107922a3461240cac2d378af5844619a408ce                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5NDExNzEzOQAAAAlfX2NyZWF0ZWQKCjEzOTQxMzMw\nOTEAAAAJX191cGRhdGVk\n	1396554271
session:8db1b1cf49da6a0513fc674c65b9954b62ae8704                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwoK\nMTM5NDEzODI4MQAAAAlfX2NyZWF0ZWQEAwAAAAEIgQAAAAJpZAAAAAZfX3VzZXIIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk2NTU2MDUzAAAACV9fdXBkYXRlZA==\n	1398975255
session:b421354aecac7138685278348d0d456eda3f0d3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDA2ODgAAAAJX19jcmVhdGVkCgoxMzk0\nMjAwNjg4AAAACV9fdXBkYXRlZA==\n	1396619888
session:cc2095f3314d28f9b6db2c87303a841e7a4b24d1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDQ4MTcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA0ODE3AAAACV9fdXBkYXRlZA==\n	1396875792
session:a18f035e3567fff3a60a32aeaaf9d5a92cde25b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDA2ODYAAAAJX19jcmVhdGVkCgoxMzk0\nMjAwNjg2AAAACV9fdXBkYXRlZA==\n	1396619890
session:09456b3a1f45dc3c9db4588b6cb6d8f81df6ee1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQxMjI5NDcAAAAJX19jcmVhdGVkCgoxMzk0\nMTIyOTQ3AAAACV9fdXBkYXRlZA==\n	1396638921
session:606ce77e8cec29a6a58449cc6c4ba40a681a0d54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDA4NTIAAAAJX19jcmVhdGVkCgoxMzk0\nMjAwODUyAAAACV9fdXBkYXRlZA==\n	1396620053
session:5afc8dc956b55b90c2398217fd09102702c5b83e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDM0MDkAAAAJX19jcmVhdGVkCgoxMzk0\nMjAzNDA5AAAACV9fdXBkYXRlZA==\n	1396622924
session:e18961944f9792c85f9cd62456925ae8960a0303                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjAAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYwAAAACV9fdXBkYXRlZA==\n	1396628360
session:c473453e90d1c23173ade33cec8c2d08c48889c0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjAAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIwAAAACV9fdXBkYXRlZA==\n	1397346620
session:a35140bb18974e2111224a1b85a27b77c7ab7271                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjAAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYwAAAACV9fdXBkYXRlZA==\n	1396628360
session:71f0a1bc89d3d35aacbdfbed8e1a1dc0cc26b7c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjAAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYwAAAACV9fdXBkYXRlZA==\n	1396628360
session:6d059ef51553fb3a82d93df8dcfa0201d8900e43                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTM0MzEAAAAJX19jcmVhdGVkCgoxMzk0\nNDkzNDMxAAAACV9fdXBkYXRlZA==\n	1396912631
session:510aa52a319afe4cc4a4cf372a9c61d1e62e74c6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NzYAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjc2AAAACV9fdXBkYXRlZA==\n	1397521876
session:c5bdecc9d731b76f38ac52d596bb6a48c96d6870                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYxAAAACV9fdXBkYXRlZA==\n	1396628361
session:f4930bebdbb7c03fe1716e63f4252f9d6f310a09                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYxAAAACV9fdXBkYXRlZA==\n	1396628361
session:3f2751459c19234510b588126fc1cbdc491fd987                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYxAAAACV9fdXBkYXRlZA==\n	1396628361
session:f8ba3171c4478043df3abcde81d5199ce18fe7d1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjIAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYyAAAACV9fdXBkYXRlZA==\n	1396628362
session:796c70dcfb3f4f07362c5e1f5e2d0f4394324775                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:2a6848aa49cda8055a7f3a95aff800197b314592                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:038deff90cff5c10807c39e3145f62236a4b0260                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:04d03152db50dd92b88cd3d42bf58ef711a35102                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628363
session:f6b51db0f28bb304aeb639f198c5d6c1e848dc92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:6b93350edf3b68aaff09285446e3a0140bbf77fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:4a660001a9ec0ff9e85d41d9e76e93a1aa4dab46                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:12e53bf1b64832868d4f6949766d44f8bff31209                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:48a52981c02980e52defb2838bc29f35d34fda42                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:8d6c9463d7e22454b859114dad4df9504fbe98c7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:43512413d76fd2af47ddaf27167aaf84f7af69d0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjYAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY2AAAACV9fdXBkYXRlZA==\n	1396628366
session:6cfd3078ee1b2cb8e66cc7fe6348f43ed26f6fb4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjYAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY2AAAACV9fdXBkYXRlZA==\n	1396628366
session:a8718c46088f95f582e5dbf1b0dca04ada01f95d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:8d5242a0eea5c0f1ae035c8151e14c496975847f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:6ace0284f3e939817f8d13953820a4b524da86bc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:80b0fa0279dbaf700c0057b5ec88a2b0ad9e6445                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:416421c5bade8be85b28fd73abaafab5fdd0c180                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:41217f58c4a07c6efbf505a2ba4e10bbc80d106b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:9e7ea187a28adf370df8cffb6d2a3caa6e0ca5ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:4ede211a030e4e83f5e6919885ea5c448766dd7b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:52e58a66d02184888c1ad76ea3e36eabe91fd532                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjkAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY5AAAACV9fdXBkYXRlZA==\n	1396628369
session:c7633d79bf205cfdadcbf11d1b9ba8a618235ac8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjkAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY5AAAACV9fdXBkYXRlZA==\n	1396628369
session:9ae35b60835e6d0670c0e02d4ab7cde349474ae8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcxAAAACV9fdXBkYXRlZA==\n	1396628371
session:b75378b29edb4807e9531092ac6ed576506ac935                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzIAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcyAAAACV9fdXBkYXRlZA==\n	1396628372
session:1d47d1d882190137160911a3c3f7ebea8d915a06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzIAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcyAAAACV9fdXBkYXRlZA==\n	1396628372
session:fa3321e07f7d87947cff4d13acf31677b8530983                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0MzY2NDAAAAAJX19jcmVhdGVkCgoxMzk2\nNDM2NjQwAAAACV9fdXBkYXRlZA==\n	1398855840
session:313e8ea2a1b3dc8325e2da13e51f9afc13f1083c                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiDAAAAAmlkAAAABl9fdXNlcgoKMTM5NDEzODM2NAAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk1NzU5Mzg2AAAACV9fdXBkYXRlZA==\n	1398191188
session:691feeb6d791d92e51d65e54c9bab5045068c641                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0NTYwNjcAAAAJX19jcmVhdGVkCgoxMzk2\nNDU2MDY3AAAACV9fdXBkYXRlZA==\n	1398875267
session:b5cbc72f0c5dcae88b92c7efc4c649e0f78587a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0NzIyMzYAAAAJX19jcmVhdGVkCgoxMzk2\nNDcyMjM2AAAACV9fdXBkYXRlZA==\n	1398891436
session:c31fde1c93c69c6af4bbf297d9a6828dd457d8bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0ODM0MDQAAAAJX19jcmVhdGVkCgoxMzk2\nNDgzNDA0AAAACV9fdXBkYXRlZA==\n	1398902604
session:513df67220552b40658d3cb343d670677b23188f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MTExNjUAAAAJX19jcmVhdGVkCgoxMzk2\nNTExMTY1AAAACV9fdXBkYXRlZA==\n	1398930365
session:d7b9862d6ebfb88930afafd9bb966dfaf5c1b441                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MTI5MDUAAAAJX19jcmVhdGVkCgoxMzk2\nNTEyOTA2AAAACV9fdXBkYXRlZA==\n	1398932105
session:0b8163eb5187229befb0068da5a93791d0903afa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYxAAAACV9fdXBkYXRlZA==\n	1396628361
session:8c79a241a90e6a01e5a466ca87444ad10bc27c57                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYxAAAACV9fdXBkYXRlZA==\n	1396628361
session:6342aa386c0a0b049ae66c35ee78b4c823d3ce32                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:545cb4a5583c587509299a01be96efc6c1c6e6fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:d4bef45a6089f440e98ceb7845e651d671a6f677                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTYzAAAACV9fdXBkYXRlZA==\n	1396628363
session:5ee0f0e47318fd118713b5987d06563720d458d7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjMAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628363
session:8d56321731991904a45c173b413f87af0e1498f7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:b39139e006fb13859be6dec837602538390efa92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:ef050447404463285c0bb3214a7d1d3cd9b3d9e8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjQAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY0AAAACV9fdXBkYXRlZA==\n	1396628364
session:59516160032a5ff95d10b3d08d3fe2e3cf00efca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:f2e0610b3cf8c49f42d825faca8b0e204b8ae3db                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:8bebdf27bcf07bc1f92b51afe3149f82d30ab5f7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:103110217f2674ccbe41e2b1a1aa0dd4cd4050c9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjUAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY1AAAACV9fdXBkYXRlZA==\n	1396628365
session:f6e864727e0d9a7440734f1e40a193c7692581cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjYAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY2AAAACV9fdXBkYXRlZA==\n	1396628366
session:f2a0db6146c19bc197e9f0583979d76c7a990f31                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:90498ad3c570692129f4ff11676fdf4b092900b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:bad5e0e0322ad80b92f03747ed741700ee5b5d41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:f301556687f09d02ae236cda193750163f403424                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjcAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY3AAAACV9fdXBkYXRlZA==\n	1396628367
session:17f30f8d4c3b782824f12017b681bc6f573cb63f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:4200d632c7aabac31c4f81e44cbeea7e5d20e40b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:5e1dffc302c2ac9b610dda89934bdeb63409dc54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:198f5c951a55b7d94f189e69705cbf4f44f3e1d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY4AAAACV9fdXBkYXRlZA==\n	1396628368
session:c36124e67a5bda927d33d5154c25540e1b469181                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjkAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY5AAAACV9fdXBkYXRlZA==\n	1396628369
session:543e713c9057c13b968617ab483ec75565ad9910                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNjkAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTY5AAAACV9fdXBkYXRlZA==\n	1396628369
session:cfdf2fb2a82ff96b8840f699050cb6f8bd0d6a18                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzAAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcwAAAACV9fdXBkYXRlZA==\n	1396628370
session:973ecbcfe6fdf1635f7c04de1c2c361273c582f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzEAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcxAAAACV9fdXBkYXRlZA==\n	1396628371
session:c7e2f3e852ac59ce8b946c33f3f6e04cf02784bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzIAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcyAAAACV9fdXBkYXRlZA==\n	1396628372
session:4bb32e272f151638bfc255f4d9393ba0affc6c85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDkxNzIAAAAJX19jcmVhdGVkCgoxMzk0\nMjA5MTcyAAAACV9fdXBkYXRlZA==\n	1396628372
session:8927b31fba3383e336acda71901b2686fec38be8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMjIxMTYAAAAJX19jcmVhdGVkCgoxMzk0\nMjIyMTE3AAAACV9fdXBkYXRlZA==\n	1396653670
session:d269b58c2a8068ba564279506259393aa037de42                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDU3MjgAAAAJX19jcmVhdGVkCgoxMzk0\nMjA1NzI5AAAACV9fdXBkYXRlZA==\n	1396629512
session:a4cee8038ec63c57687125601993aa9718b7ec28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMjIzOTEAAAAJX19jcmVhdGVkCgoxMzk0\nMjIyMzkxAAAACV9fdXBkYXRlZA==\n	1396641620
session:306f7215551d48ea23b949cd5ae9802629be9562                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQzMjM0NzEAAAAJX19jcmVhdGVkCgoxMzk0\nMzIzNDcxAAAACV9fdXBkYXRlZA==\n	1396742671
session:79e57d8a7b52f5aa4a8cc99385737e6107dd16bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQzODE2MjMAAAAJX19jcmVhdGVkCgoxMzk0\nMzgxNjIzAAAACV9fdXBkYXRlZA==\n	1396800823
session:848f5afc51943412988a03673dc14583d2f45ddd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQzNDk2MzAAAAAJX19jcmVhdGVkCgoxMzk0\nMzQ5NjMwAAAACV9fdXBkYXRlZA==\n	1396768830
session:1bf831aa8c34b6c733a9773a2b8099578f068deb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0MzgxMTkAAAAJX19jcmVhdGVkCgoxMzk0\nNDM4MTE5AAAACV9fdXBkYXRlZA==\n	1396857319
session:d6c8396e308528ab69f486e012d1d9b4bc3d36e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0NDc4ODUAAAAJX19jcmVhdGVkCgoxMzk0\nNDQ3ODg1AAAACV9fdXBkYXRlZA==\n	1396867085
session:319ced53f28a39d35723c16e831f29d40c289780                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTM0MzAAAAAJX19jcmVhdGVkCgoxMzk0\nNDkzNDMwAAAACV9fdXBkYXRlZA==\n	1396912630
session:c852a9fed36ce24cffb38484b945da1b4e617e03                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0NTY2NjQAAAAJX19jcmVhdGVkCgoxMzk0\nNDU2NjY0AAAACV9fdXBkYXRlZA==\n	1396875865
session:c35f52fc6e05bf3349faebe425ce957f266a2a0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0NTY4MTgAAAAJX19jcmVhdGVkCgoxMzk0\nNDU2ODE4AAAACV9fdXBkYXRlZA==\n	1396876018
session:73d420130f8df827efa275fce5810b4f1dc68b3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk3AAAACV9fdXBkYXRlZA==\n	1396954997
session:a75d2ee91571097f2ab4d9fb6441eec0c0e36af9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0NjUyMDQAAAAJX19jcmVhdGVkCgoxMzk0\nNDY1MjA0AAAACV9fdXBkYXRlZA==\n	1396884405
session:dda16beb756b7fc7bdad2759962f58469a960839                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0NzEzMzgAAAAJX19jcmVhdGVkCgoxMzk0\nNDcxMzM4AAAACV9fdXBkYXRlZA==\n	1396890538
session:b67520a79b390cd09e9fb09e38f8240703f1bf5e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk4AAAACV9fdXBkYXRlZA==\n	1396954998
session:5a741555a168dd93116b10bffcd5d34849e75fc3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk5AAAACV9fdXBkYXRlZA==\n	1396954999
session:68983096bddda0910d080715ed30a40d04beb566                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk5AAAACV9fdXBkYXRlZA==\n	1396954999
session:d49a6e306920a43f92f9df332fc6422bdee1aae4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAwAAAACV9fdXBkYXRlZA==\n	1396955000
session:40ec13c62129899289d0a60f5f8b3544b2c66da4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAxAAAACV9fdXBkYXRlZA==\n	1396955001
session:362248be3b91d23d58741db68a37a092ee0fd312                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAxAAAACV9fdXBkYXRlZA==\n	1396955001
session:628a6e9301235dbaa402939319086ff08f30ef1a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTM0MzAAAAAJX19jcmVhdGVkCgoxMzk0\nNDkzNDMwAAAACV9fdXBkYXRlZA==\n	1396912630
session:2c0778e748292066a2278bdfb3f4af1bd469380f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTM0MzEAAAAJX19jcmVhdGVkCgoxMzk0\nNDkzNDMxAAAACV9fdXBkYXRlZA==\n	1396912631
session:d2ff2999d8c66d441b5c4e69c6cc4c2e1c4304ea                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MTYzMTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTE2MzE1AAAACV9fdXBkYXRlZA==\n	1396935515
session:1870512897225f644c41ae5ae1792d15e2de2289                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzAzNzIAAAAJX19jcmVhdGVkCgoxMzk0\nNTMwMzcyAAAACV9fdXBkYXRlZA==\n	1396949572
session:f4dcf6f35ec1a6c812160299cc6f654c2fac823b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk2AAAACV9fdXBkYXRlZA==\n	1396954996
session:096ff72852b8db4133095a4b1d092a7ce0d7ba97                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAyAAAACV9fdXBkYXRlZA==\n	1396955002
session:a85d3168c28e84daf7266ea2b32a2f43eabe799b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAzAAAACV9fdXBkYXRlZA==\n	1396955003
session:10f204d07ae621dc65577915c07e92e5264a833f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA0AAAACV9fdXBkYXRlZA==\n	1396955004
session:1102d0725402bbca62c5e25d77a41cc8003e185d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA0AAAACV9fdXBkYXRlZA==\n	1396955004
session:cd5e6f8fbe0409c332751d43f3534c83fa8b6479                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA1AAAACV9fdXBkYXRlZA==\n	1396955005
session:1236400e0ef52efe40e0d2b1440963223b91880a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA2AAAACV9fdXBkYXRlZA==\n	1396955006
session:699c1f8e5cc40b8c34b590408a6fddafc5a0b1fe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA2AAAACV9fdXBkYXRlZA==\n	1396955006
session:70b3caf933a136a06ef8dd7a769acbfa7ec43fb9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA3AAAACV9fdXBkYXRlZA==\n	1396955007
session:15055907d479975f4eea60b45a19649097088f92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA4AAAACV9fdXBkYXRlZA==\n	1396955008
session:703f73743a0fc7c80d077d64d8bc00996cc6e5c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA4AAAACV9fdXBkYXRlZA==\n	1396955008
session:2928cefe6c9040731ca9587986d23f66fb4d2d74                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA5AAAACV9fdXBkYXRlZA==\n	1396955009
session:ceee01259bba71f8b25bbd1553c7d90b68c9dcfb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEwAAAACV9fdXBkYXRlZA==\n	1396955010
session:b5c6d24dc6fc9ae1e24d25f30af34cde9f8d95a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEwAAAACV9fdXBkYXRlZA==\n	1396955010
session:d4fe43c77b70f0518e4dfab53561d233ec45f582                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODExAAAACV9fdXBkYXRlZA==\n	1396955011
session:2643fcd92bb2bc4aff3342198e28843a9fba6830                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEyAAAACV9fdXBkYXRlZA==\n	1396955012
session:3bb028810c8e581cf1116644aa2456e95a55d379                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEyAAAACV9fdXBkYXRlZA==\n	1396955012
session:5794d303a018caff36f302704223314be9bac65f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEzAAAACV9fdXBkYXRlZA==\n	1396955013
session:be6e4af6e2cc84d790aa4cc35c8d7514fe2968ef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE0AAAACV9fdXBkYXRlZA==\n	1396955014
session:1cf47b54cbeeb430362f5d05f50b0934f1b84b17                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU3OTMxMzQAAAAJX19jcmVhdGVkCgoxMzk1\nNzkzMTM0AAAACV9fdXBkYXRlZA==\n	1398212334
session:305218c456758b65c4abd922364e1f144d8cfcf1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MTYyNzkAAAAJX19jcmVhdGVkCgoxMzk0\nNTE2Mjc5AAAACV9fdXBkYXRlZA==\n	1396935479
session:8e021291c369a81d4668d0f262852203814c0221                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MjE0MzkAAAAJX19jcmVhdGVkCgoxMzk0\nNTIxNDM5AAAACV9fdXBkYXRlZA==\n	1396940639
session:9df130c99a28ab1e13c06e774f1614ddffd1567b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk2AAAACV9fdXBkYXRlZA==\n	1396954995
session:8fbde34d4ad42527682144eeb2fea6ecc1360ea7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk3AAAACV9fdXBkYXRlZA==\n	1396954997
session:3525bb9fef2ed6706e95fd5deeca03ac58b2dcc3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk4AAAACV9fdXBkYXRlZA==\n	1396954998
session:1244e8ebbcc33dd6140dfb4cf6c007dc99ac0ab5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk4AAAACV9fdXBkYXRlZA==\n	1396954998
session:55e4dbb823eb73d7d7f00d236ea051d03474fc1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU3OTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1Nzk5AAAACV9fdXBkYXRlZA==\n	1396954999
session:1651d8c04b298de4ecf10f141770add5cc57a24e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAwAAAACV9fdXBkYXRlZA==\n	1396955000
session:aa7dde6a11d269e901fcb5ff4b8a169c8e53a035                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAwAAAACV9fdXBkYXRlZA==\n	1396955000
session:52c44ba29fa6cd579ff3fe22698ea6b15633da5e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAxAAAACV9fdXBkYXRlZA==\n	1396955001
session:571736212462fcd7826cfabbbc859ac28128970f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAyAAAACV9fdXBkYXRlZA==\n	1396955002
session:654eccc939c06dcfe45db3d8ecce0d99b148a26f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAzAAAACV9fdXBkYXRlZA==\n	1396955003
session:b1df9b26acf2898ad43a75fdc1c7d8295a6406bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODAzAAAACV9fdXBkYXRlZA==\n	1396955003
session:0782ea03d5eb14fcb51f38fb7582241387dcf566                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA0AAAACV9fdXBkYXRlZA==\n	1396955004
session:62433370c1441ea64cbd2339d9f77833695734a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA1AAAACV9fdXBkYXRlZA==\n	1396955005
session:d2c6be598e811507a71ed695df942390f392db7c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA1AAAACV9fdXBkYXRlZA==\n	1396955005
session:63f4c3290293a71b47fa30bf1515bad6e164e920                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA2AAAACV9fdXBkYXRlZA==\n	1396955006
session:38b3a70d8674031ae476c99cf3e7146f94a0a6f9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA3AAAACV9fdXBkYXRlZA==\n	1396955007
session:e824b5e7c618d63ac2fcae76689b52eed19e43c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA3AAAACV9fdXBkYXRlZA==\n	1396955007
session:d900df4365ec33911dc1260cab003c74e7da352c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA4AAAACV9fdXBkYXRlZA==\n	1396955008
session:0fdbb326fc0fe8665383576b4b22b0e474c03549                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA5AAAACV9fdXBkYXRlZA==\n	1396955009
session:b401414ddaf6aede907d360e449c627359679fdf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MDkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODA5AAAACV9fdXBkYXRlZA==\n	1396955009
session:7a041469ff83a64f054208980740b19fafd65b39                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEwAAAACV9fdXBkYXRlZA==\n	1396955010
session:0f6c09bf912a4f3bdc0f40ad333f51c9273f2b77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODExAAAACV9fdXBkYXRlZA==\n	1396955011
session:f64139ae9aef78ff86b8b4a43c7f5491567e30e3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODExAAAACV9fdXBkYXRlZA==\n	1396955011
session:6c3de1f9eab66e1ed25436e1b8314e546bfe6180                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEyAAAACV9fdXBkYXRlZA==\n	1396955012
session:8e2a1a5e3331008285265966f804871f36a45175                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEzAAAACV9fdXBkYXRlZA==\n	1396955013
session:6233d733bde7903e4b94f9b8aa60ff88a5998f38                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODEzAAAACV9fdXBkYXRlZA==\n	1396955013
session:f4dc3140b2dbd240b09160ea4ffaf5494620f5f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE0AAAACV9fdXBkYXRlZA==\n	1396955014
session:8b6bef613d9548f98fb305c5061b70e04ec98816                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE1AAAACV9fdXBkYXRlZA==\n	1396955015
session:455908084f35be32f92ff428652cb53ac1bbc6b6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE1AAAACV9fdXBkYXRlZA==\n	1396955015
session:f112f6b61bea50d479abe735500ae2f542200d00                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE2AAAACV9fdXBkYXRlZA==\n	1396955016
session:d705b9a8d7869ff7d53cf9bc0595e6dfd0041cf4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE3AAAACV9fdXBkYXRlZA==\n	1396955017
session:23a98a2a06518470df07d1773669d9c8a74c8d6b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE3AAAACV9fdXBkYXRlZA==\n	1396955017
session:a8b623635e38790615566904f37967624eea0600                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE4AAAACV9fdXBkYXRlZA==\n	1396955018
session:c9c8180c15ab1139cb616abcefcf7c8330ddcd66                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE5AAAACV9fdXBkYXRlZA==\n	1396955019
session:e775b330f1bf86c9ef8dd559217416f33289fa29                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE5AAAACV9fdXBkYXRlZA==\n	1396955019
session:309e7858e214956f6cdba9a270bbf7d0d8ebfaa0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTQAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE0AAAACV9fdXBkYXRlZA==\n	1396955014
session:10a127bd7e014f38aa66f69506adcb371acd3bc7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE1AAAACV9fdXBkYXRlZA==\n	1396955015
session:291f1741142a65cafabfca80f2527d9468a2eb25                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE2AAAACV9fdXBkYXRlZA==\n	1396955016
session:9b5be74a5a36aefa2ae0ea5760d9b6453aa82843                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTYAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE2AAAACV9fdXBkYXRlZA==\n	1396955016
session:586cbd085acba4641611302923bb325afab35dd6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTcAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE3AAAACV9fdXBkYXRlZA==\n	1396955017
session:7d8266e03c71adca292492324a083fc86bb3d4a0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE4AAAACV9fdXBkYXRlZA==\n	1396955018
session:fa38f0a42b80e52e3545f6316fea527f6c74b3df                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTgAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE4AAAACV9fdXBkYXRlZA==\n	1396955018
session:8d84215716dd04e37d375be65d2f62d3b7cf9e54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MTkAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODE5AAAACV9fdXBkYXRlZA==\n	1396955019
session:cb248429db49b353e31c7ccb4e8fc3b8af644d29                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIwAAAACV9fdXBkYXRlZA==\n	1396955020
session:31b19f42409bed27d2abd5e8d31a02b3284fc94c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIwAAAACV9fdXBkYXRlZA==\n	1396955020
session:79af7cbb2e2d57fc3d16c8950d10d7096753753c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIxAAAACV9fdXBkYXRlZA==\n	1396955021
session:c47b3481acd76b65ab7b65e74d2aec4d573d951a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIyAAAACV9fdXBkYXRlZA==\n	1396955022
session:97c7f3a42cece16f85f7cb6890d224d3a38200f6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIyAAAACV9fdXBkYXRlZA==\n	1396955022
session:7521e1266b16e846a0a2f6a7ddc79e63609c7fa3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIzAAAACV9fdXBkYXRlZA==\n	1396955023
session:e801242adc01a4dc0d7369ac372ef49ed5ac33bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MDQ0MTkAAAAJX19jcmVhdGVkCgoxMzk1\nODA0NDE5AAAACV9fdXBkYXRlZA==\n	1398223619
session:4d80a2e5e7217deaf07e075d65f66204f1c51af1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM1MjkAAAAJX19jcmVhdGVkCgoxMzk1\nODMzNTI5AAAACV9fdXBkYXRlZA==\n	1398252729
session:dd42c6ea5b6bbea0ba2ac4aa30dd957c0063aade                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:7ac5701387f1371c2d8c29e160c7f56edf2c77b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:ca7debdaf6abbe0a7c989142f16d8dc2206501b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:3bcafc30246a7bed207cf03aa9ec644548bfa906                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MzEAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODMxAAAACV9fdXBkYXRlZA==\n	1398253031
session:7eec404c2e2e4980f26139244161793844f4d67d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MzYAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODM2AAAACV9fdXBkYXRlZA==\n	1398253036
session:178e02957c566c731e5b138e0a2e05de02aa3741                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4NDYAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODQ2AAAACV9fdXBkYXRlZA==\n	1398253046
session:5f522b1ec99d731ff2f2f057137efc9cf9f451b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM5MTAAAAAJX19jcmVhdGVkCgoxMzk1\nODMzOTEwAAAACV9fdXBkYXRlZA==\n	1398253110
session:6cab309adfc05afa151e40113d8cdad7ee6614b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NDc4MjEAAAAJX19jcmVhdGVkCgoxMzk1\nODQ3ODIxAAAACV9fdXBkYXRlZA==\n	1398267021
session:f4ae3ae5cc144fd4fddcb4a6fee8281c5f56cf6b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NTkzNTAAAAAJX19jcmVhdGVkCgoxMzk1\nODU5MzUwAAAACV9fdXBkYXRlZA==\n	1398278550
session:7e65b9a9b2b22e5b25f0b3888fb343e978a0c896                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5MDQzNTcAAAAJX19jcmVhdGVkCgoxMzk1\nOTA0MzU3AAAACV9fdXBkYXRlZA==\n	1398323557
session:9f8c4bdf15fae4160444fdfb54f5c93e8f3f744d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5MTg1NjUAAAAJX19jcmVhdGVkCgoxMzk1\nOTE4NTY1AAAACV9fdXBkYXRlZA==\n	1398337765
session:cceb73f9a5f7144e3b8c786dcca3d7832915dd9a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5NzU2NDcAAAAJX19jcmVhdGVkCgoxMzk1\nOTc1NjQ3AAAACV9fdXBkYXRlZA==\n	1398394847
session:b55ce5e070895ee4f1d092a702e967f8c5242eba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5OTY2ODUAAAAJX19jcmVhdGVkCgoxMzk1\nOTk2Njg1AAAACV9fdXBkYXRlZA==\n	1398415885
session:734d2d06a9c39798cf37a7a27c80ff7b22377d5e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwMTU1NTMAAAAJX19jcmVhdGVkCgoxMzk2\nMDE1NTUzAAAACV9fdXBkYXRlZA==\n	1398434753
session:bcfd6d91d76422b564f3df1a278f2a71ebe81cdd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwMzY3MDQAAAAJX19jcmVhdGVkCgoxMzk2\nMDM2NzA0AAAACV9fdXBkYXRlZA==\n	1398455904
session:493a8dc39d3c82eb3488e4fcb5e39b1936e94301                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwNzA5NjgAAAAJX19jcmVhdGVkCgoxMzk2\nMDcwOTY4AAAACV9fdXBkYXRlZA==\n	1398490168
session:f90c4291d4079e6a92d02eca4a70f19ed7d8621a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwOTcxOTcAAAAJX19jcmVhdGVkCgoxMzk2\nMDk3MTk3AAAACV9fdXBkYXRlZA==\n	1398516397
session:0ed8f077c5363e9c3b304f6ff778d15a20b79307                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxMDgxNDkAAAAJX19jcmVhdGVkCgoxMzk2\nMTA4MTQ5AAAACV9fdXBkYXRlZA==\n	1398527349
session:2362257238e0582d845bc251daf1b081e47cd85d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxMzUyODUAAAAJX19jcmVhdGVkCgoxMzk2\nMTM1Mjg1AAAACV9fdXBkYXRlZA==\n	1398554485
session:21928f33d6efdb79f2b011399b246734361de591                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxNjg5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMTY4OTc2AAAACV9fdXBkYXRlZA==\n	1398588176
session:4b77d50bf94919811a2f98cea777e91165770fb7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyNDI4NDMAAAAJX19jcmVhdGVkCgoxMzk2\nMjQyODQzAAAACV9fdXBkYXRlZA==\n	1398662043
session:33f9f684711e7210487d5de77fb9a687e2a99d81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjAAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIwAAAACV9fdXBkYXRlZA==\n	1396955020
session:724881c218ac5ef58a2f3011ba96945aed73db1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIxAAAACV9fdXBkYXRlZA==\n	1396955021
session:c0f7bc58edc4c0028a0dc5d6c48afc9d408f4f9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjEAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIxAAAACV9fdXBkYXRlZA==\n	1396955021
session:dedbb769619d02193ef2389f761a0fda7c853f6f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjIAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIyAAAACV9fdXBkYXRlZA==\n	1396955022
session:c376bd041c0412879ba6e16787f61d010fe46201                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1MzU4MjMAAAAJX19jcmVhdGVkCgoxMzk0\nNTM1ODIzAAAACV9fdXBkYXRlZA==\n	1396955023
session:9f15dc99d53f113a833b6ca3e97bb7726573a6d3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1NDYwMDYAAAAJX19jcmVhdGVkCgoxMzk0\nNTQ2MDA2AAAACV9fdXBkYXRlZA==\n	1396965206
session:09f55ba62ff3cc2f4ab568749b6276d0bc8a3512                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1NTI5ODUAAAAJX19jcmVhdGVkCgoxMzk0\nNTUyOTg1AAAACV9fdXBkYXRlZA==\n	1396972185
session:4bca95908e911778ef2d1b834c77389450dffd39                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1NTgxNTUAAAAJX19jcmVhdGVkCgoxMzk0\nNTU4MTU1AAAACV9fdXBkYXRlZA==\n	1396977355
session:531f92f409f5861488e125d137bf25e2d3824caa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1NzI3ODUAAAAJX19jcmVhdGVkCgoxMzk0\nNTcyNzg1AAAACV9fdXBkYXRlZA==\n	1396991985
session:739e875892a3d68851a7dbb4a0f7a9a32ee84cb0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1ODA1NDQAAAAJX19jcmVhdGVkCgoxMzk0\nNTgwNTQ0AAAACV9fdXBkYXRlZA==\n	1396999744
session:4d2b3557c3c843b4d8bd3c8be3180b52e8a988ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ1ODM2MjcAAAAJX19jcmVhdGVkCgoxMzk0\nNTgzNjI3AAAACV9fdXBkYXRlZA==\n	1397002827
session:b890e855cd86a6ff5df6ea28ffb04debff40c2be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MDM1MjgAAAAJX19jcmVhdGVkCgoxMzk0\nNjAzNTI4AAAACV9fdXBkYXRlZA==\n	1397022728
session:436f8097271adcac1e4ff9db15e780447a1c0f88                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MjE5ODcAAAAJX19jcmVhdGVkCgoxMzk0\nNjIxOTg4AAAACV9fdXBkYXRlZA==\n	1397041187
session:d2e3f3d3d0a8eba3f6e2feac6786276c74131db6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MjQ3OTYAAAAJX19jcmVhdGVkCgoxMzk0\nNjI0Nzk2AAAACV9fdXBkYXRlZA==\n	1397043996
session:313181794cff101981720e843a6710b1f0551e87                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MjY1NDcAAAAJX19jcmVhdGVkCgoxMzk0\nNjI2NTQ3AAAACV9fdXBkYXRlZA==\n	1397045747
session:99a63c1be39d6ea2c7aff25a7d335784b6c41e64                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MzY1NzEAAAAJX19jcmVhdGVkCgoxMzk0\nNjM2NTcxAAAACV9fdXBkYXRlZA==\n	1397055771
session:09fa1ff5449902533d6cd1b1a3409c082b0ae9cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTE3NzkAAAAJX19jcmVhdGVkCgoxMzk0\nNjUxNzc5AAAACV9fdXBkYXRlZA==\n	1397071187
session:5d80441c7e6145eb7bbc9dba6c06b3af34a1f2e3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTM1NjIAAAAJX19jcmVhdGVkCgoxMzk0\nNjUzNTYyAAAACV9fdXBkYXRlZA==\n	1397072762
session:f2f8253aa53d43c0cffb4c2f4e05d8ee33222dff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTM1NjIAAAAJX19jcmVhdGVkCgoxMzk0\nNjUzNTYyAAAACV9fdXBkYXRlZA==\n	1397072762
session:b76f9f9f3bc4bea65c6b690fd29f855a0e214716                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NDc4ODQAAAAJX19jcmVhdGVkCgoxMzk0\nNjQ3ODg0AAAACV9fdXBkYXRlZA==\n	1397067084
session:bfc50c7c02d3d240a93be87de950c829c10efd94                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NjUxNTIAAAAJX19jcmVhdGVkCgoxMzk0\nNjY1MTUyAAAACV9fdXBkYXRlZA==\n	1397084352
session:e4f2a6f657118ff8c0882ff0637c375fcb0e4eda                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTkzOTgAAAAJX19jcmVhdGVkCgoxMzk0\nNjU5Mzk5AAAACV9fdXBkYXRlZA==\n	1397078603
session:c87121a7eb915cffc7d032492d4e2d012cf43c8a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTUxODYAAAAJX19jcmVhdGVkCgoxMzk0\nNjU1MTg2AAAACV9fdXBkYXRlZA==\n	1397074386
session:46527f6b4a862ef9337f9f25b4138dde545d3abd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NDE1NDAAAAAJX19jcmVhdGVkCgoxMzk0\nNjQxNTQwAAAACV9fdXBkYXRlZA==\n	1397068076
session:8bfb24f3f5024545eb2bca16fb5a583cf0857525                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NzU0MjYAAAAJX19jcmVhdGVkCgoxMzk0\nNjc1NDI2AAAACV9fdXBkYXRlZA==\n	1397094626
session:f0ba8b2116d567ecf1a6cea247404b704c1e066a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQyMDA4MjYAAAAJX19jcmVhdGVkCgoxMzk0\nNjU5MzY5AAAACV9fdXBkYXRlZA==\n	1397078585
session:902663c5aac41ecdf2b1858484b67f4bdffefd70                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2MzkyMTQAAAAJX19jcmVhdGVkCgoxMzk0\nNjM5MjE0AAAACV9fdXBkYXRlZA==\n	1397129980
session:24e7c7c478dc95ad3c7b8958c4df35b757522988                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NzcyMzAAAAAJX19jcmVhdGVkCgoxMzk0\nNjc3MjMwAAAACV9fdXBkYXRlZA==\n	1397096430
session:f52f752752b6a880d5bd608a34b736870286a07f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NTk0MzIAAAAJX19jcmVhdGVkCgoxMzk0\nNjU5NDMyAAAACV9fdXBkYXRlZA==\n	1397078637
session:431b071ab15e115d1c5f711f56b9f0432203a21c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NjUxNTEAAAAJX19jcmVhdGVkCgoxMzk0\nNjY1MTUxAAAACV9fdXBkYXRlZA==\n	1397084351
session:eaa10aaacb733b85f2b51df34ce5f559e4a133fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2ODE2MzcAAAAJX19jcmVhdGVkCgoxMzk0\nNjgxNjM3AAAACV9fdXBkYXRlZA==\n	1397100838
session:f03db78c78a9a21fd3afceb3af2495932c21bb72                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2OTU2NDYAAAAJX19jcmVhdGVkCgoxMzk0\nNjk1NjQ3AAAACV9fdXBkYXRlZA==\n	1397114846
session:9167937aa121c516de56e09eb9264d507327c62f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2OTc4NjMAAAAJX19jcmVhdGVkCgoxMzk0\nNjk3ODYzAAAACV9fdXBkYXRlZA==\n	1397117063
session:a1f1d97150184c82be849d4080e7d7bd7ed6654e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3MDEwODgAAAAJX19jcmVhdGVkCgoxMzk0\nNzAxMDg4AAAACV9fdXBkYXRlZA==\n	1397120288
session:1954dc3d5268ff9afd5bf802f8a530ac1d23a243                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3MDI0NTgAAAAJX19jcmVhdGVkCgoxMzk0\nNzAyNDU4AAAACV9fdXBkYXRlZA==\n	1397121658
session:43a42e3b2aa78ef7b3d711a45a79a03cf5b2e67b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjAAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIwAAAACV9fdXBkYXRlZA==\n	1397346620
session:1b5e5d863b311f8639ef6134120ae0543778d060                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjAAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIwAAAACV9fdXBkYXRlZA==\n	1397346620
session:d3f75410419c902e9812c9ed266c193734a32eaa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjEAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODIxAAAACV9fdXBkYXRlZA==\n	1398253021
session:9cd678548ae4a472103e5e67311412b996423bc1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:4ba3596bcc3d930d0f8fb9fa12c673952c307127                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:39be6c2a959e73657a79e14a2155680c500bdbe1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MjcAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODI3AAAACV9fdXBkYXRlZA==\n	1398253027
session:c43e79291ab5810ba4cf719129863d28741862b6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4MzMAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODMzAAAACV9fdXBkYXRlZA==\n	1398253033
session:447c6f5a09d885a24aa03538bad4100f7ac77901                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4NDAAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODQwAAAACV9fdXBkYXRlZA==\n	1398253040
session:9d5218fd64812881d69d14c191026d91eb6421be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzM4NTAAAAAJX19jcmVhdGVkCgoxMzk1\nODMzODUwAAAACV9fdXBkYXRlZA==\n	1398253050
session:c59e4af9721ca6dc416ed1864eedb37c50555eb3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4MzU2NDcAAAAJX19jcmVhdGVkCgoxMzk1\nODM1NjQ3AAAACV9fdXBkYXRlZA==\n	1398254847
session:e53da31d0b701be2c009d3358194189fb050d13d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3MTQ3NDIAAAAJX19jcmVhdGVkCgoxMzk0\nNzE0NzQzAAAACV9fdXBkYXRlZA==\n	1397134579
session:56200b59ea27a173321e80e08a90e80e9287ec74                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3MzA2NTQAAAAJX19jcmVhdGVkCgoxMzk0\nNzMwNjU0AAAACV9fdXBkYXRlZA==\n	1397149854
session:cdbb8849714901b4f8fa2980b5fbba38654c44fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3NjM5ODQAAAAJX19jcmVhdGVkCgoxMzk0\nNzYzOTg0AAAACV9fdXBkYXRlZA==\n	1397183184
session:0a829d474839c5e89af361a006e5604af164b027                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3NjY0MjEAAAAJX19jcmVhdGVkCgoxMzk0\nNzY2NDIxAAAACV9fdXBkYXRlZA==\n	1397185621
session:760a4555069f9ddf9afc54ac451ddddafb092004                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3ODE4MDMAAAAJX19jcmVhdGVkCgoxMzk0\nNzgxODAzAAAACV9fdXBkYXRlZA==\n	1397201003
session:77440cca4b9b4e3b7f86d8232fdeb1c477f39ed5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NDUyMTMAAAAJX19jcmVhdGVkCgoxMzk1\nODQ1MjEzAAAACV9fdXBkYXRlZA==\n	1398264413
session:88abe1abd51cd5d6753cdd009167cf55db44af13                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NTYyNjAAAAAJX19jcmVhdGVkCgoxMzk1\nODU2MjYwAAAACV9fdXBkYXRlZA==\n	1398275460
session:2a69f3959572d9f17c13a57de151b957630972f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwNzA5NjgAAAAJX19jcmVhdGVkCgoxMzk2\nMDcwOTY4AAAACV9fdXBkYXRlZA==\n	1398490168
session:15a50dcbdd20cbc7f0fb4804eba62194b729e5ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NjYwNzkAAAAJX19jcmVhdGVkCgoxMzk1\nODY2MDgwAAAACV9fdXBkYXRlZA==\n	1398285290
session:9131c47f3f13bb14bc093b1d62523c88b8c7f9a6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU4NzM5MzUAAAAJX19jcmVhdGVkCgoxMzk1\nODczOTM1AAAACV9fdXBkYXRlZA==\n	1398293135
session:132f7d353208fbd808180bb2b63ac316a19b5434                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5MTU3NzAAAAAJX19jcmVhdGVkCgoxMzk1\nOTE1NzcwAAAACV9fdXBkYXRlZA==\n	1398334970
session:831cc433022573c0d66df0272419635c98e8d355                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU5MjAwNzAAAAAJX19jcmVhdGVkCgoxMzk1\nOTIwMDcwAAAACV9fdXBkYXRlZA==\n	1398339270
session:a7cc66fdaffd910aa569271433ee4ac1fba7ae49                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwNzA5NjgAAAAJX19jcmVhdGVkCgoxMzk2\nMDcwOTY4AAAACV9fdXBkYXRlZA==\n	1398490168
session:d7a7928658f65e0339edb2119b05fb6f0c2aec2c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0NDIzNDcAAAAJX19jcmVhdGVkCgoxMzk2\nNDQyMzQ3AAAACV9fdXBkYXRlZA==\n	1398861547
session:e6c944de7509cab37c7644505a3da2729ac53004                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwMDEwMTkAAAAJX19jcmVhdGVkCgoxMzk2\nMDAxMDE5AAAACV9fdXBkYXRlZA==\n	1398420219
session:763985b82c6614b062539dcfab450109a7d3099b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYwMjY1NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMDI2NTc3AAAACV9fdXBkYXRlZA==\n	1398445777
session:142371b7e87383fe1c70dc0e7d4f3f495f6bb0da                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxMDc4MDIAAAAJX19jcmVhdGVkCgoxMzk2\nMTA3ODAyAAAACV9fdXBkYXRlZA==\n	1398527002
session:03d138d3d1047d93fc2e79c81bb81aa27e6ca88e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxMjk4OTYAAAAJX19jcmVhdGVkCgoxMzk2\nMTI5ODk2AAAACV9fdXBkYXRlZA==\n	1398549096
session:2fc41e5130f4801685a39127869321b1faaaaff8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYxNTc1NjEAAAAJX19jcmVhdGVkCgoxMzk2\nMTU3NTYxAAAACV9fdXBkYXRlZA==\n	1398576761
session:e5f082534c57632635f33a3a0d9a8ad57020bd57                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyMzUwNTQAAAAJX19jcmVhdGVkCgoxMzk2\nMjM1MDU0AAAACV9fdXBkYXRlZA==\n	1398654254
session:93c5ddfd9f08e24d17eb3ec1a34a082d7adca5c6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyNDI4NTYAAAAJX19jcmVhdGVkCgoxMzk2\nMjQyODU2AAAACV9fdXBkYXRlZA==\n	1398662056
session:08c548ebf98db87848faabd55dee049f04050f12                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0NTM1MzUAAAAJX19jcmVhdGVkCgoxMzk2\nNDUzNTM1AAAACV9fdXBkYXRlZA==\n	1398872735
session:55510c10be72defe9aaf929a1c784229ad4d18bc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY0NzI2MDEAAAAJX19jcmVhdGVkCgoxMzk2\nNDcyNjAxAAAACV9fdXBkYXRlZA==\n	1398891801
session:14c520e2214b7076966d4f69ad5ba0739cbc629c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUyNDcwMjYAAAAJX19jcmVhdGVkCgoxMzk1\nMjQ3MDI2AAAACV9fdXBkYXRlZA==\n	1400014118
session:7d33fe8e098c5b0650a303719de3481cf31c3322                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MDYzNDUAAAAJX19jcmVhdGVkCgoxMzk2\nNTA2MzQ1AAAACV9fdXBkYXRlZA==\n	1398925545
session:bedcc9a6998bb2d2d03a3a2c807b6faad33b270c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MTE3NDcAAAAJX19jcmVhdGVkCgoxMzk2\nNTExNzQ3AAAACV9fdXBkYXRlZA==\n	1398930947
session:f209c5ee346b5f1b7c237155dde1a4d19ee64d70                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MjI1NzAAAAAJX19jcmVhdGVkCgoxMzk2\nNTIyNTcwAAAACV9fdXBkYXRlZA==\n	1398941770
session:0ab517de19e269af0ee60b6befdde1400b40a97b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1ODMyNDMAAAAJX19jcmVhdGVkCgoxMzk2\nNTgzMjQzAAAACV9fdXBkYXRlZA==\n	1399002443
session:a28470682ddd7730a5488feacd6c28f52fc08033                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3NTk5MDUAAAAJX19jcmVhdGVkCgoxMzk0\nNzU5OTA1AAAACV9fdXBkYXRlZA==\n	1397179104
session:14aa9d2b36ac9fa7439b2fa08cc9069353fa4162                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3NjQ4NjYAAAAJX19jcmVhdGVkCgoxMzk0\nNzY0ODY2AAAACV9fdXBkYXRlZA==\n	1397184066
session:6b1fb2ac3c55cdb2cbea07be1b6cd29d4ce25b67                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3ODQxMDIAAAAJX19jcmVhdGVkCgoxMzk0\nNzg0MTAyAAAACV9fdXBkYXRlZA==\n	1397203302
session:6af26597c65f1f31f70acda4efbb2e66150ce84f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3ODY3MzcAAAAJX19jcmVhdGVkCgoxMzk0\nNzg2NzM3AAAACV9fdXBkYXRlZA==\n	1397205937
session:8d6d7ef968665ade75f2bbbd57df0f85d39c0549                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ3OTg5NDkAAAAJX19jcmVhdGVkCgoxMzk0\nNzk4OTQ5AAAACV9fdXBkYXRlZA==\n	1397218149
session:797b74c1a0dd294099f1b5f2f5034272c8e8eb1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTYAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE2AAAACV9fdXBkYXRlZA==\n	1397346616
session:ad13fcaf3a0af54cc0aa317eb07cfe152e490fd2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTYAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE2AAAACV9fdXBkYXRlZA==\n	1397346616
session:9afc839e4ecd62b5218ad885a3e3e91c52beb260                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ2NDY2OTUAAAAJX19jcmVhdGVkCgoxMzk0\nNjQ2Njk1AAAACV9fdXBkYXRlZA==\n	1397226675
session:db2fac3c853013d6f7c0b0a4fc6fad7c25ed54db                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4MzkxMzcAAAAJX19jcmVhdGVkCgoxMzk0\nODM5MTM3AAAACV9fdXBkYXRlZA==\n	1397258337
session:22acf1b88ab53384e576e83f723ae6e8765962a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4NDA3MzUAAAAJX19jcmVhdGVkCgoxMzk0\nODQwNzM1AAAACV9fdXBkYXRlZA==\n	1397259935
session:52b386d71d9d45ba111c62d99fc8e904d9c8305f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4NDE2MTEAAAAJX19jcmVhdGVkCgoxMzk0\nODQxNjExAAAACV9fdXBkYXRlZA==\n	1397260811
session:ea566aaa2c149c5863b561d597e6f51ab85f67b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4NDE2MTEAAAAJX19jcmVhdGVkCgoxMzk0\nODQxNjExAAAACV9fdXBkYXRlZA==\n	1397260811
session:02dee1f4a3008608ed9afdef5b414e8dc2696e22                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4NTEzNTEAAAAJX19jcmVhdGVkCgoxMzk0\nODUxMzUxAAAACV9fdXBkYXRlZA==\n	1397270551
session:a7a4a51ec789e36e4046d5e5274028369afb1afa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4NTc5OTAAAAAJX19jcmVhdGVkCgoxMzk0\nODU3OTkwAAAACV9fdXBkYXRlZA==\n	1397277190
session:8e1df19b4f53abc303d1750c0f8cd69230e39fff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ4OTM3NjYAAAAJX19jcmVhdGVkCgoxMzk0\nODkzNzY2AAAACV9fdXBkYXRlZA==\n	1397312966
session:1e927462810edcdb3c2934b5e47ff181d3e8e2fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTIAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDEzAAAACV9fdXBkYXRlZA==\n	1397346612
session:646768fe32b27ec1e16f3bf1675f2a2989a4f3c0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTIAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDEzAAAACV9fdXBkYXRlZA==\n	1397346612
session:a3704d41fac4bf4c4e3f9e2cf2115d6d33f53e6e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE0AAAACV9fdXBkYXRlZA==\n	1397346613
session:280be5cf3c24ee8b141d4dbb01bd4510d6728fe7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE0AAAACV9fdXBkYXRlZA==\n	1397346613
session:5027130e746d1447df6cac6927ab2c481e15a68c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE0AAAACV9fdXBkYXRlZA==\n	1397346614
session:bb561a8039d52a38237ba2db04cc6b07a17e2f61                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE0AAAACV9fdXBkYXRlZA==\n	1397346614
session:341de5604a605f7013a04c85275d31b169b2e379                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE0AAAACV9fdXBkYXRlZA==\n	1397346614
session:16c4a8c44a733a4fcd00c65fb436391d86241032                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE1AAAACV9fdXBkYXRlZA==\n	1397346614
session:715dd9144128025a1e9b51c3a9a4bbc88c7d5a28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTcAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE3AAAACV9fdXBkYXRlZA==\n	1397346617
session:31e44d484d7235b23675b9406728079cc364ed48                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTcAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE3AAAACV9fdXBkYXRlZA==\n	1397346617
session:8c00a8af920a483339d0493dba79c5d3128a18bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTcAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE3AAAACV9fdXBkYXRlZA==\n	1397346617
session:04159c5f46954c016f73d7b7db0ba21bf8913b79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTcAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE3AAAACV9fdXBkYXRlZA==\n	1397346617
session:d9e4cd1ffa1a1331cad12a00b60e73395e96a6c1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTcAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE3AAAACV9fdXBkYXRlZA==\n	1397346617
session:211f3ec5750a67cdb460a25347d8ae05adce31d9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE4AAAACV9fdXBkYXRlZA==\n	1397346617
session:4e507dd86706e2ff3da66fd331a361784a0d5f29                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE4AAAACV9fdXBkYXRlZA==\n	1397346618
session:a67adc6aa57dbcd2dfc1398da8cf9d5d19502603                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE4AAAACV9fdXBkYXRlZA==\n	1397346618
session:8fe3f73bd7bf5fc1acfbbc601fb27417cba3cfee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE4AAAACV9fdXBkYXRlZA==\n	1397346618
session:312af18d852bc154d908e2ffb809d009f4ff7164                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE5AAAACV9fdXBkYXRlZA==\n	1397346618
session:abe30266892147de889b01c61b019be8469de79d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE5AAAACV9fdXBkYXRlZA==\n	1397346619
session:cbdbaf7fec27628087ac6f8a93dc3f509e5ba48b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE5AAAACV9fdXBkYXRlZA==\n	1397346619
session:0a3eda39459dba9716ee5b4f1ec391562917bc08                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDE5AAAACV9fdXBkYXRlZA==\n	1397346619
session:89afc31ce649b5243b88183037293fc7c2cae533                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MTkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIwAAAACV9fdXBkYXRlZA==\n	1397346619
session:308f88a96f12cdd51f0d8190716080ac03563cf2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjEAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIxAAAACV9fdXBkYXRlZA==\n	1397346620
session:c0eaa6c02ddf089d6f3bfb94245491784fe37d5f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjEAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIxAAAACV9fdXBkYXRlZA==\n	1397346621
session:eb5fee0771069a6e0b04b75797f3681bfa72cbac                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjIAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIyAAAACV9fdXBkYXRlZA==\n	1397346622
session:fa43d129fa0179e63f22d55759156e783ba41e8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjIAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIyAAAACV9fdXBkYXRlZA==\n	1397346622
session:90bab815210fd2fd2757333cf294126778dae58d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIzAAAACV9fdXBkYXRlZA==\n	1397346623
session:21f60308a5ca7d9feec445769b26c1035f49ab44                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIzAAAACV9fdXBkYXRlZA==\n	1397346623
session:a40a41179139a308e5a464b77fccf9c99225fd37                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:73c092303a8938096d552f6dec0d9981d210f617                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:0507bd8147e59c86580e68bbcae3de7f1e7dd489                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:8536ccbee8b1e0a5cca6959dbd1fbaebd5502ff7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:c315354a8f3acaa29bab3b1841fef26894f9a5d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI1AAAACV9fdXBkYXRlZA==\n	1397346625
session:574a76a347d9ae0e18ee063b28f56bb561700e44                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI1AAAACV9fdXBkYXRlZA==\n	1397346625
session:25059d2f926d54bd68db36e5642a8d06ba8ab45a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjYAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI2AAAACV9fdXBkYXRlZA==\n	1397346626
session:748b9895ee6693158597bb44540937ff707a1e1a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjYAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI2AAAACV9fdXBkYXRlZA==\n	1397346626
session:f638a5c161c37a2586a93087f16d433f79f1b3a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI4AAAACV9fdXBkYXRlZA==\n	1397346628
session:af7eb868e7735188b25fe453bb640969176248c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI4AAAACV9fdXBkYXRlZA==\n	1397346628
session:37a3f3d5dc5291d7c0dafb7b122ed294aa863a30                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI5AAAACV9fdXBkYXRlZA==\n	1397346629
session:e07fe7ee8caacb0ddb62eba81719c8ebf2643ddf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTE5MDUAAAAJX19jcmVhdGVkCgoxMzk2\nNTkxOTA1AAAACV9fdXBkYXRlZA==\n	1399011105
session:3dd3e8d3e3c4b31efb7964906785033ce8aa1612                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTQ5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nNTk0OTgxAAAACV9fdXBkYXRlZA==\n	1399014181
session:dd9e5259be633e0ac911097ddf54aae922d0512e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyNzYxMjkAAAAJX19jcmVhdGVkCgoxMzk2\nMjc2MTI5AAAACV9fdXBkYXRlZA==\n	1398695346
session:ff0341104e0023b5b9abce78a6f6f9a164608a45                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2MDc4MjEAAAAJX19jcmVhdGVkCgoxMzk2\nNjA3ODIxAAAACV9fdXBkYXRlZA==\n	1399027021
session:babc0ebc766f113e29f7a04b33eb7b897d9fbd52                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTkAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU5AAAACV9fdXBkYXRlZA==\n	1399066659
session:b48e71ea0c205bd0c13e7a43f668abf09d66c1be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MzA3MDEAAAAJX19jcmVhdGVkCgoxMzk2\nNTMwNzAxAAAACV9fdXBkYXRlZA==\n	1400788012
session:875e1cfc047ad2ffc8848d7ee02fcac940723543                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1MzYzOTcAAAAJX19jcmVhdGVkCgoxMzk2\nNTM2Mzk3AAAACV9fdXBkYXRlZA==\n	1398955597
session:080ae8899df70034123dea0eb2834850d202e722                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1NjMyNzYAAAAJX19jcmVhdGVkCgoxMzk2\nNTYzMjc2AAAACV9fdXBkYXRlZA==\n	1398982476
session:216edd48f3d1e6c5f39e3b1f00820f09fe937fd8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTE5MDIAAAAJX19jcmVhdGVkCgoxMzk2\nNTkxOTAyAAAACV9fdXBkYXRlZA==\n	1399011102
session:dab9a1d37b6be38dffc9f1b1231617e2d5202a48                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY1OTE5MDMAAAAJX19jcmVhdGVkCgoxMzk2\nNTkxOTAzAAAACV9fdXBkYXRlZA==\n	1399011103
session:b2326d8db77d5ac17aad61da1b9be6133534e61d                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5NjYyMTc1NgAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk2NjIxNzU2AAAACV9fdXBkYXRlZA==\n	1399040958
session:bc7dc291324019c0abb85a4af0b8aee3d6a2feb4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTYAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU2AAAACV9fdXBkYXRlZA==\n	1399066656
session:0b9229ee1956a15cba60023cf2817c010db2c6c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NTgAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDU4AAAACV9fdXBkYXRlZA==\n	1399066658
session:9cdb109f791fa8a0f7ccc84f71c5eade0bebdc76                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjAAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYwAAAACV9fdXBkYXRlZA==\n	1399066660
session:910d055e3abd3b30f505e5f065e128302788ffd8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjIAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYyAAAACV9fdXBkYXRlZA==\n	1399066662
session:6adc5ffa97addf1f4928a94f5a3e504f0012039c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2NDc0NjMAAAAJX19jcmVhdGVkCgoxMzk2\nNjQ3NDYzAAAACV9fdXBkYXRlZA==\n	1399066663
session:0caa68b765a1f02e662efffaa32bf32483baa9fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY2ODk4OTEAAAAJX19jcmVhdGVkCgoxMzk2\nNjg5ODkxAAAACV9fdXBkYXRlZA==\n	1399109091
session:f32cf4f4bc7d45ad03e0f7b0a040d3b30fc114ce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODAAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgwAAAACV9fdXBkYXRlZA==\n	1399202280
session:b2f7c96644b7463e8c2d7ebe5337261b9d92b47b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTY3ODMwODEAAAAJX19jcmVhdGVkCgoxMzk2\nNzgzMDgxAAAACV9fdXBkYXRlZA==\n	1399202281
session:08fb779f9ca05e4e1af970c291bd8f6c07cea31b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjEAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIxAAAACV9fdXBkYXRlZA==\n	1397346620
session:374777a8b1212ba5af2abc85c5952b4326be0e28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjEAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIyAAAACV9fdXBkYXRlZA==\n	1397346621
session:e8e7ce1d70efc59df0caba6a828c4fc66597cd53                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjIAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIyAAAACV9fdXBkYXRlZA==\n	1397346622
session:adcccd06ab5c56b16da191c852ea107588ec934d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIzAAAACV9fdXBkYXRlZA==\n	1397346623
session:b5c6cd19d7e3c9fc155194a9cd1a07caf2f2760a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDIzAAAACV9fdXBkYXRlZA==\n	1397346623
session:c44f65cef2617053e3b3dd11ed74d5810319a4af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjMAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346623
session:b0e1b74982f1ef9de9a0cdcef946605635cdd40c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:2803c885ac0dfd267b6a5b93df99876dd2daa689                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:c6dd673456058a1534548b717bb50823faaf033f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjQAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI0AAAACV9fdXBkYXRlZA==\n	1397346624
session:4f6327fa693dc80c2164426f34e5f48d3c0b81bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI1AAAACV9fdXBkYXRlZA==\n	1397346625
session:8b0d307c9b2a5f29c1b6d3a49e56706f32d566be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI1AAAACV9fdXBkYXRlZA==\n	1397346625
session:08c23998de23764fb098bb6157e3e28725cb343e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjUAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI1AAAACV9fdXBkYXRlZA==\n	1397346625
session:d821208de2fe589f0418460ba408fa2d36b58eaf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjYAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI2AAAACV9fdXBkYXRlZA==\n	1397346626
session:2a00fd75773f72ed803180e447cc6eef9e2f8a79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI4AAAACV9fdXBkYXRlZA==\n	1397346628
session:3c21feb50289323e24ac3acae75dbba7066d08e8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjgAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI5AAAACV9fdXBkYXRlZA==\n	1397346628
session:023d9d7c06037fa0e09e5aee85fb51cf91244fc4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Mjc0MjkAAAAJX19jcmVhdGVkCgoxMzk0\nOTI3NDI5AAAACV9fdXBkYXRlZA==\n	1397346629
session:7609fe572ad5079579f74a7e4700aa9ad1e26876                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5NTU0OTgAAAAJX19jcmVhdGVkCgoxMzk0\nOTU1NDk4AAAACV9fdXBkYXRlZA==\n	1397374698
session:c17a593a57a00190c5ccdfc65991783da8cd7549                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5NTYxMzMAAAAJX19jcmVhdGVkCgoxMzk0\nOTU2MTMzAAAACV9fdXBkYXRlZA==\n	1397375333
session:f740834c131d8e28150a01092ed22dbbd833ec9e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5Njk2OTAAAAAJX19jcmVhdGVkCgoxMzk0\nOTY5NjkwAAAACV9fdXBkYXRlZA==\n	1397388890
session:c34420e933b44e36b7743ff681d90154ef13e58d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ5ODcxNTUAAAAJX19jcmVhdGVkCgoxMzk0\nOTg3MTU1AAAACV9fdXBkYXRlZA==\n	1397406355
session:8b45da2b9c5aaf12ff23c76e4d545a7f0db0f7a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwMjgxODgAAAAJX19jcmVhdGVkCgoxMzk1\nMDI4MTg4AAAACV9fdXBkYXRlZA==\n	1397447388
session:83d25714d00c1d94594b646539dde1a0b6b8993a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwMjg1MjMAAAAJX19jcmVhdGVkCgoxMzk1\nMDI4NTI0AAAACV9fdXBkYXRlZA==\n	1397447723
session:5c8799772e05f7d5b728d4eafca6db1d94b03bd6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwMzU0MTMAAAAJX19jcmVhdGVkCgoxMzk1\nMDM1NDE0AAAACV9fdXBkYXRlZA==\n	1397454613
session:66e12ac7893eff4e295be4ba356566e1236648b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNTU4ODIAAAAJX19jcmVhdGVkCgoxMzk1\nMDU1ODgyAAAACV9fdXBkYXRlZA==\n	1397475082
session:eca3023694840afe72c5800db25121afa89f82ab                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNTYwNDIAAAAJX19jcmVhdGVkCgoxMzk1\nMDU2MDQyAAAACV9fdXBkYXRlZA==\n	1397475242
session:a919459db9f9f73d9ee2d888072b0956b07f345a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNTYxMTgAAAAJX19jcmVhdGVkCgoxMzk1\nMDU2MTE4AAAACV9fdXBkYXRlZA==\n	1397475318
session:af7578d152386ff83c0bbe4b1acafaa392ce595f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNTkyNzgAAAAJX19jcmVhdGVkCgoxMzk1\nMDU5Mjc4AAAACV9fdXBkYXRlZA==\n	1397478478
session:bf7184480a7209f96239fea68843873a1705bf58                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNzY5MTkAAAAJX19jcmVhdGVkCgoxMzk1\nMDc2OTE5AAAACV9fdXBkYXRlZA==\n	1397496119
session:642cc3f53eed2216a25a82194ed45e75f7cbcbd2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwODc3OTYAAAAJX19jcmVhdGVkCgoxMzk1\nMDg3Nzk2AAAACV9fdXBkYXRlZA==\n	1397506996
session:cd0f8ad475cd16fb1ab430ddc7513582d704bd41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNjYwMDMAAAAJX19jcmVhdGVkCgoxMzk1\nMDY2MDAzAAAACV9fdXBkYXRlZA==\n	1397487571
session:131f7ef9348fe1163e613b9ed53a84199a6d47f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwNzMxNzAAAAAJX19jcmVhdGVkCgoxMzk1\nMDczMTcwAAAACV9fdXBkYXRlZA==\n	1397492370
session:98b76e34228d40d39cb826d3ec57e7fe4c18b66d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwODc4MzIAAAAJX19jcmVhdGVkCgoxMzk1\nMDg3ODMyAAAACV9fdXBkYXRlZA==\n	1397507032
session:f9de492990bdeef4d51a5d415c0dd60fe54dacb8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUwOTY5MjcAAAAJX19jcmVhdGVkCgoxMzk1\nMDk2OTI3AAAACV9fdXBkYXRlZA==\n	1397516127
session:9f9fa2cadb409cdff5bca5c7ead03f081bdf3917                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NjYAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjY3AAAACV9fdXBkYXRlZA==\n	1397521866
session:7871672db854d00b417deb263bb09e3135086a1d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NjcAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjY3AAAACV9fdXBkYXRlZA==\n	1397521867
session:c6d323ecc0c38b6a5ef4fe01da4afd622108cae7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NjgAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjY4AAAACV9fdXBkYXRlZA==\n	1397521868
session:0d430785748e698cd165d24a0de963916ed48a41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NzUAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjc1AAAACV9fdXBkYXRlZA==\n	1397521875
session:16d4a99bac65f8cf23b931fc40576b61cdd77843                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2NzYAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjc2AAAACV9fdXBkYXRlZA==\n	1397521876
session:85e3f4e06c368d4a8e6cb3855042d155a49af16a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2ODEAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjgxAAAACV9fdXBkYXRlZA==\n	1397521881
session:fee909ada8ca8c02fda086f740ac029cfe858dd2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMTExOTQAAAAJX19jcmVhdGVkCgoxMzk1\nMTExMTk0AAAACV9fdXBkYXRlZA==\n	1397530394
session:9f34f14f7ac14340f4f4b52a089f395f914d8554                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMjY2MTMAAAAJX19jcmVhdGVkCgoxMzk1\nMTI2NjEzAAAACV9fdXBkYXRlZA==\n	1397545813
session:05b49cae2626baeb041c6a6cd7ebfa7cd8d6532c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxNjYxOTkAAAAJX19jcmVhdGVkCgoxMzk1\nMTY2MTk5AAAACV9fdXBkYXRlZA==\n	1397585399
session:ee3eb4232727da675e9bb9fd10e44f6305d131cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyODczNzYAAAAJX19jcmVhdGVkCgoxMzk2\nMjg3Mzc2AAAACV9fdXBkYXRlZA==\n	1398706576
session:1742ebaeb46d540f36cc93972ea4b57226e50ef0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyODk3MDgAAAAJX19jcmVhdGVkCgoxMzk2\nMjg5NzA4AAAACV9fdXBkYXRlZA==\n	1398708908
session:5aa15bb6052a9492e70884f2c09a3e9ecb7a022b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzMDQ5ODgAAAAJX19jcmVhdGVkCgoxMzk2\nMzA0OTg4AAAACV9fdXBkYXRlZA==\n	1398724188
session:81fffac3f4737d4c4731cf762ea7a9128de33313                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzMzk3MDMAAAAJX19jcmVhdGVkCgoxMzk2\nMzM5NzAzAAAACV9fdXBkYXRlZA==\n	1398758903
session:0906d116c530e161412a18534f37ac56b713f09d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzNTAwODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzUwMDgxAAAACV9fdXBkYXRlZA==\n	1398769281
session:fd854f21cef32837583356242ddef579464c42bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc1AAAACV9fdXBkYXRlZA==\n	1398802175
session:505e71c1d39cc1eb3712de6c01b149b7656819b1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:2ddb818bfabeb2bf036e4f7612a6262cac625462                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:7b3a450ff5872efa99f6248b21ac3e052999074a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:50b50d8f9b22a74a2fa476cca4f892ac094a8d8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802176
session:674804efd79fe835c4a32f12620a8cb086e9f1f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802177
session:a230644d490bd2e26af84d3ea6bb5bff9e553a20                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802177
session:66819f1c94cc3ec396c3d0ff97dddc2d7c418619                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzgAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc4AAAACV9fdXBkYXRlZA==\n	1398802178
session:0d7748f14dbec4ad008155555e2f43dfe2bcc913                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:b3d429bc6f8960248c9bd002df9d6c17b843f5f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:083bd081cecfb344fb396584bb6c56a29867abdf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:45c35aa2610193fccd76a7f399cebf19eb72c470                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:cab3c8780a0baba784983824b1e9f8385a1bebaf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:2826e1a62b07460e1f2ce99d45758b8cf55a9a4d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802179
session:86e2d5ad53340fbe18b9ef8f52dae143f5efa899                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:c8102bab94f66a81d744063fe52d30252debe30e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:e7d9a4978e020eef5c3766e6d6bf0056ca93e905                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:3ce7583f590210940a6410d4f4c1ca3324530396                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:8ee34f25625c8c8cb9fc08aab4d793ac1d85f74f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:b7a76a3440dded706b46be9aa6665373482dee76                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:913e13aa369c172ee003f2af7e4bbf3ae6dc40d9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:bfc29cbca3892c0739eb9554037fffbc21acf2ee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:2ed062cbe7624ee0f368cb34c650da9720c57021                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:7cda2f5e359a70a3db76e7df6a81f964b2b4a84f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:b2726d9b3042e2dc64c35c44398fcc56aee1e097                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:b34d8dd7516ef7fc297c069360ea526361f1a1a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:9573c63188d4d415377dafb84c8dad5519a1b929                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:5ea834b8ca33e85b4aa6979248c263f753c60af5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2ODAAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjgwAAAACV9fdXBkYXRlZA==\n	1397521880
session:1087c46eb6be74fe4f14790f265407741dfb9f6c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMDI2ODIAAAAJX19jcmVhdGVkCgoxMzk1\nMTAyNjgyAAAACV9fdXBkYXRlZA==\n	1397521882
session:a87f0521e2e9c92187c76c9780281e3f47e23955                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxMjE5MDcAAAAJX19jcmVhdGVkCgoxMzk1\nMTIxOTA3AAAACV9fdXBkYXRlZA==\n	1397541107
session:3a2e502d045caea0cfa934a37570881bdd4c3743                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxNTE1OTMAAAAJX19jcmVhdGVkCgoxMzk1\nMTUxNTkzAAAACV9fdXBkYXRlZA==\n	1397570793
session:bafeda9c55b0fad048374bc54f1f0a86cec1d8c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxNjEzNjMAAAAJX19jcmVhdGVkCgoxMzk1\nMTYxMzYzAAAACV9fdXBkYXRlZA==\n	1397580563
session:41ab56f6b50d888689ffff3ae123514f3c40159f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxNjg1OTkAAAAJX19jcmVhdGVkCgoxMzk1\nMTY4NTk5AAAACV9fdXBkYXRlZA==\n	1397587799
session:74ce0282d21ab61bfd57306f5222cee3a25b3f51                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUxNzUxODMAAAAJX19jcmVhdGVkCgoxMzk1\nMTc1MTgzAAAACV9fdXBkYXRlZA==\n	1397594383
session:67b6841b3d9caadb7577b08f939bd399deb51f9c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUyMTU2NzkAAAAJX19jcmVhdGVkCgoxMzk1\nMjE1Njc5AAAACV9fdXBkYXRlZA==\n	1397634879
session:530b46931a91bbd7809bb1123df8b6852df35c5e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUyMzA1MTIAAAAJX19jcmVhdGVkCgoxMzk1\nMjMwNTEyAAAACV9fdXBkYXRlZA==\n	1397649712
session:46950fa94be13e0342b0df6eb2d13fddcc35a99c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUyMzI5NTkAAAAJX19jcmVhdGVkCgoxMzk1\nMjMyOTU5AAAACV9fdXBkYXRlZA==\n	1397652159
session:03abfe2792682e8d54639ca05c034c711701462a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU1NjMwOTEAAAAJX19jcmVhdGVkCgoxMzk1\nNTYzMDkxAAAACV9fdXBkYXRlZA==\n	1397982291
session:2933b3715e8e5ce6b7bc62719d195c952a14c51c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2MjU1MjYAAAAJX19jcmVhdGVkCgoxMzk1\nNjI1NTI2AAAACV9fdXBkYXRlZA==\n	1398044726
session:e64c50aeec74fa78848082f58d0b062ef771f4fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUyOTMzNTAAAAAJX19jcmVhdGVkCgoxMzk1\nMjkzMzUwAAAACV9fdXBkYXRlZA==\n	1397712550
session:8e6938fd6366a86a90ea8e3005f5e093abd56c59                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzMDI3NzMAAAAJX19jcmVhdGVkCgoxMzk1\nMzAyNzczAAAACV9fdXBkYXRlZA==\n	1397721973
session:f13481c42572f1a71cacca47440cca66cb33b8ff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzMjAyNjAAAAAJX19jcmVhdGVkCgoxMzk1\nMzIwMjYwAAAACV9fdXBkYXRlZA==\n	1397739460
session:2f78c6f1b6d03a51d19ae2388fef3328af68ea47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzMjY5MzYAAAAJX19jcmVhdGVkCgoxMzk1\nMzI2OTM2AAAACV9fdXBkYXRlZA==\n	1397746136
session:0f07d9c514ac828ab230582e3f4b8b53f2ed3729                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzMzYyMzkAAAAJX19jcmVhdGVkCgoxMzk1\nMzM2MjM5AAAACV9fdXBkYXRlZA==\n	1397755439
session:59a2a6428e18ba082170ef2d41f3fc907590d02c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU1NzMxNzAAAAAJX19jcmVhdGVkCgoxMzk1\nNTczMTcwAAAACV9fdXBkYXRlZA==\n	1397992370
session:da9b5fb2c746595edfc027dafc73358ea2678485                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzNDYxNTEAAAAJX19jcmVhdGVkCgoxMzk1\nMzQ2MTUxAAAACV9fdXBkYXRlZA==\n	1397765534
session:218937115471393f22a91b7a6476768e6a035ab5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzNDY4MTQAAAAJX19jcmVhdGVkCgoxMzk1\nMzQ2ODE0AAAACV9fdXBkYXRlZA==\n	1397766014
session:5ff0d5886940d5c19b81d905f7f0c007778292b4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzNTA1MjQAAAAJX19jcmVhdGVkCgoxMzk1\nMzUwNTI0AAAACV9fdXBkYXRlZA==\n	1397769724
session:28bb683e3f2890580e88c97f4bed9075ed1ae2d0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2MzcwNDQAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3MDQ0AAAACV9fdXBkYXRlZA==\n	1398056243
session:1f4cb68aec70441fbda80708abe753f5184e9f1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzNzc1OTkAAAAJX19jcmVhdGVkCgoxMzk1\nMzc3NTk5AAAACV9fdXBkYXRlZA==\n	1397796799
session:8bc83b83a12a265adc03946f724a849315370e77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzOTA4MDAAAAAJX19jcmVhdGVkCgoxMzk1\nMzkwODAwAAAACV9fdXBkYXRlZA==\n	1397809999
session:3cd7c62b881c01a8ce901a704b0b655b1387a89d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTUzOTk2MzUAAAAJX19jcmVhdGVkCgoxMzk1\nMzk5NjM1AAAACV9fdXBkYXRlZA==\n	1397818835
session:2c11f92bfd5646d1359762ba230e252f4e786df0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU0MjcxNDIAAAAJX19jcmVhdGVkCgoxMzk1\nNDI3MTQyAAAACV9fdXBkYXRlZA==\n	1397846342
session:1363d41da447f160d5a045921d6594735e240703                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU1MjczODMAAAAJX19jcmVhdGVkCgoxMzk1\nNTI3MzgzAAAACV9fdXBkYXRlZA==\n	1397946583
session:168f32c7a46640b8b0c5053b036f918a597a881b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU1NTgzNzYAAAAJX19jcmVhdGVkCgoxMzk1\nNTU4Mzc2AAAACV9fdXBkYXRlZA==\n	1397977576
session:973ace572bf591cedcab4092ebc02ab5dca334c0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2MDMyNzkAAAAJX19jcmVhdGVkCgoxMzk1\nNjAzMjc5AAAACV9fdXBkYXRlZA==\n	1398022479
session:caf423b4c086416bb5fa19ac1b229a093b1cfca4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2MTc4NjgAAAAJX19jcmVhdGVkCgoxMzk1\nNjE3ODY4AAAACV9fdXBkYXRlZA==\n	1398037068
session:990f698de1894a29f9b16c9a1110a69ba14ba4e8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2MzczOTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3MzkyAAAACV9fdXBkYXRlZA==\n	1398056592
session:0c09dcaa20f2260e67b197234b1bf0747f84b2c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0MjQAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDI0AAAACV9fdXBkYXRlZA==\n	1398056624
session:035128806ac699359bfdd4e0c9cb241b2e09f464                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0MjcAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDI3AAAACV9fdXBkYXRlZA==\n	1398056627
session:02c6df4c102560b214b717997e2d55774b72529d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0MjgAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDI4AAAACV9fdXBkYXRlZA==\n	1398056628
session:a97824e5105de6a35225ed1d8110f7e25260b7cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0MjgAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDI4AAAACV9fdXBkYXRlZA==\n	1398056628
session:04a1f532f474e067e9742cc5ffba8047dbb2c4d5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0MjkAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDI5AAAACV9fdXBkYXRlZA==\n	1398056629
session:6e50ce0f9c456b02f195516aafded985d13161ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDAAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQwAAAACV9fdXBkYXRlZA==\n	1398056640
session:8119228821dfab04810c95e7fc94ed32b8b0883d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDIAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQyAAAACV9fdXBkYXRlZA==\n	1398056642
session:60b49c870b39eab333fe2e1f3fc47bc44e075ac1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDQAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQ0AAAACV9fdXBkYXRlZA==\n	1398056644
session:5037fde08af2eb230879ceb74e2df24359e3b221                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDkAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQ5AAAACV9fdXBkYXRlZA==\n	1398056649
session:bf12d02bec2c25939cd829904dd7801279fc801a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYyODkwOTcAAAAJX19jcmVhdGVkCgoxMzk2\nMjg5MDk3AAAACV9fdXBkYXRlZA==\n	1398708297
session:59ef77b6badf1d52bfbdeeefbbe24592ebb869ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzMDQyMTEAAAAJX19jcmVhdGVkCgoxMzk2\nMzA0MjExAAAACV9fdXBkYXRlZA==\n	1398723411
session:b543efc055ab95423740bcef317a44fb9744583f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzMTAzNDMAAAAJX19jcmVhdGVkCgoxMzk2\nMzEwMzQzAAAACV9fdXBkYXRlZA==\n	1398729543
session:c4a20104a0e6463b61b23cd311638aef08f0d1e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzMzMwNzAAAAAJX19jcmVhdGVkCgoxMzk2\nMzMzMDcwAAAACV9fdXBkYXRlZA==\n	1398752270
session:4ae998854e854183cb17dfbe4c3bbfc6c4124f3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzNDM5NzgAAAAJX19jcmVhdGVkCgoxMzk2\nMzQzOTc4AAAACV9fdXBkYXRlZA==\n	1398763178
session:e3bd58be4d7e52ba4360e444802658d665842c63                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzUAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc1AAAACV9fdXBkYXRlZA==\n	1398802175
session:a54169f14df9ed640dc49861307c6d0ba876f1f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:fd01caa4ee9c523824feec52dd5cc8955c2291bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:1f6696042cec7b300ad773a9ef36a93b2708c10a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:03fbeb99ed2f339c9bf12d7e66578a7da6e27c30                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzYAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc2AAAACV9fdXBkYXRlZA==\n	1398802176
session:11df3ea4026b2ce8a8849980ae94ad8fcf385d81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802176
session:4e8b3e76109d1c8b26bdb6ee0b2c813ac1a9cb5c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802177
session:4f484be9a96e3923b4e2740b3c9bb6470def679d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802177
session:9a7519c545a2f4eb1e5cbe9ccd04ba0b7bcf0582                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzcAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc3AAAACV9fdXBkYXRlZA==\n	1398802177
session:64ad98fb96535b448312bce6c1fca7b6852a468d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzgAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc4AAAACV9fdXBkYXRlZA==\n	1398802178
session:3d0b35d200710bcf5855816c60198d5678da143b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:c3488475b2819eb4d956f7d9d71cee94b7938637                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:be37622a9799ed0cdc219448957286ac832a38d3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:2cf3a98cfd237f2a134f75f2bd1383da58419cdf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:d9bc84006d1f111f52290d2aa0855a1622893da7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5NzkAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTc5AAAACV9fdXBkYXRlZA==\n	1398802179
session:ca54de78ac223dd0aac850e1b207f7667396978e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:bf8b191f37b976a85b49e7f6f10932b19c001132                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:d829f8ace9c7c0ac752eadc788e51ea2fca60fcd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:f36c5d2f261d688b22e69b1a8af410d7206439ed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:f4c07793ed0f5f2d97206089a38a9ff631f5a958                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:d68ebeb7a64ce205f871cf8a41be05cef852c111                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:ddd2d63d112498ab1f9d1b599f3de6bcadd5281c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgwAAAACV9fdXBkYXRlZA==\n	1398802180
session:ff8cc21518b0a5aeacffd1317dd86fe84c373137                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODAAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802180
session:47b440070ac0e5e9a66aec30740b90727a916420                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:309a54a108108c018d2b36f40420f49dc9197644                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:0bdebd52d06bb092b64ca282c9525a05a216d37c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:2c104398652c0e9ed3497ade3cfd50fc98ba6070                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:d82ab30f0daa66ff156af3065a4d317161c1d814                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:7d33c8d1bd6d24481d83a48d761544aa0d8de067                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDEAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQxAAAACV9fdXBkYXRlZA==\n	1398056641
session:e8f2c51515bb1cf585f881b668060b8050ffe8cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDMAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQzAAAACV9fdXBkYXRlZA==\n	1398056643
session:4697bd9b3d8d0275d72bb635b02f0b5c04223898                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NDQAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDQ0AAAACV9fdXBkYXRlZA==\n	1398056644
session:052a6ef873fe0120dbbd2f82d5fc9d10b1f4f708                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0NTAAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDUwAAAACV9fdXBkYXRlZA==\n	1398056650
session:66e82bcbc00c5df6ae26b9f210f6d2c4ebdcb10a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0ODgAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDg4AAAACV9fdXBkYXRlZA==\n	1398056688
session:48a45dfbdee7960d19ab212a9ece40ad80b1623c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0ODkAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDg5AAAACV9fdXBkYXRlZA==\n	1398056689
session:665e9a3172b1fa343daee7efe7b4b2a35408ee3e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0OTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDkzAAAACV9fdXBkYXRlZA==\n	1398056693
session:c159aad81c82d2158f1b964651ce227ed1d25ba3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0OTYAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDk2AAAACV9fdXBkYXRlZA==\n	1398056696
session:32db44de2d486cc291327fc40208816f5cf219f5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc0OTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NDk3AAAACV9fdXBkYXRlZA==\n	1398056697
session:18400cce5d3d3f730490e04e42940b9717a7d0f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc1MDUAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NTA1AAAACV9fdXBkYXRlZA==\n	1398056705
session:0f02e155e6b09c4861a701b37675cd29e503b5c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc1MTYAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NTE2AAAACV9fdXBkYXRlZA==\n	1398056716
session:e6aa59c203f1d78dc8f74bd9fcc65c06a47ed1c2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc1MjkAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NTI5AAAACV9fdXBkYXRlZA==\n	1398056729
session:4fc4b91fe99def364f2980497be5faedbe5d35c9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2Mzc1NDAAAAAJX19jcmVhdGVkCgoxMzk1\nNjM3NTQwAAAACV9fdXBkYXRlZA==\n	1398056740
session:130da3300e1b53e0feeb3f63125a5ad59d1865bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NTAxMDQAAAAJX19jcmVhdGVkCgoxMzk1\nNjUwMTA0AAAACV9fdXBkYXRlZA==\n	1398069304
session:bec3475244e3b5e4865956e3ad0d34b9e6740168                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NTQ1NzcAAAAJX19jcmVhdGVkCgoxMzk1\nNjU0NTc3AAAACV9fdXBkYXRlZA==\n	1398073777
session:b4aa86e7f9ebbeedef76940a20d1672df0d6e3bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NTU5OTAAAAAJX19jcmVhdGVkCgoxMzk1\nNjU1OTkwAAAACV9fdXBkYXRlZA==\n	1398075190
session:0bdf7d97bdf17508f6e6a5d24d1a7a308c1a2cfa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA2AAAACV9fdXBkYXRlZA==\n	1398079206
session:730bda02598e86a6ad9c7cc86630a500b5af3a80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA2AAAACV9fdXBkYXRlZA==\n	1398079206
session:b44d0e4c2bc6a360aced5a7b1175212220db935a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA3AAAACV9fdXBkYXRlZA==\n	1398079207
session:66ff54390cfe5cfc48767367d31c252da5b7f5c9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA3AAAACV9fdXBkYXRlZA==\n	1398079207
session:57bce37b11cd3294ec479945f35e8786d4a99b1d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA4AAAACV9fdXBkYXRlZA==\n	1398079208
session:c7a216546f42c3f5e616b4389d708e646b05f44c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA4AAAACV9fdXBkYXRlZA==\n	1398079208
session:b9145653fbd52d210579786feddedc6e7bdfa728                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA4AAAACV9fdXBkYXRlZA==\n	1398079208
session:4070e91384b25f1f610ac22858e389e27d529866                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDA4AAAACV9fdXBkYXRlZA==\n	1398079208
session:b65379d118fa86b4e7a2a000884fba7649e29632                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMDkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEwAAAACV9fdXBkYXRlZA==\n	1398079209
session:9ed29dfcea8ad541df934df3bbae357c2fd5dff9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTAAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEwAAAACV9fdXBkYXRlZA==\n	1398079210
session:c3c3bb2705952cc7da65b60144a275e0b0b9936a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTAAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDExAAAACV9fdXBkYXRlZA==\n	1398079210
session:05ac05fa4db64936714783513899f3498e4ceb65                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEyAAAACV9fdXBkYXRlZA==\n	1398079211
session:4fecb5675db9ddd4f61cd4aa0168f7e5af5bf460                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEyAAAACV9fdXBkYXRlZA==\n	1398079211
session:bc6fa4789f6335288221d2d97e5ba041fd445812                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEyAAAACV9fdXBkYXRlZA==\n	1398079212
session:43acfc70b1ff321a03e86bb4016176365975e51c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEyAAAACV9fdXBkYXRlZA==\n	1398079212
session:98b6cff5438ebe5f9269f1d923b71f52beaf07cb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEzAAAACV9fdXBkYXRlZA==\n	1398079212
session:4557b3406fff2c8a3caa5f5e55d12c6285e77179                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTIAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEzAAAACV9fdXBkYXRlZA==\n	1398079212
session:db7ca585330dc8c8e5de698aec1464170a095042                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEzAAAACV9fdXBkYXRlZA==\n	1398079213
session:ac7e0fd4e768c3ed7abac2eee45007eedd6f21ce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDEzAAAACV9fdXBkYXRlZA==\n	1398079213
session:10b96ad54f3f66efe2b6fab0e0eabca8026340ce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE0AAAACV9fdXBkYXRlZA==\n	1398079213
session:bec3f866ce50fe35731bc16dbe0f55635b073eac                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTQAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE0AAAACV9fdXBkYXRlZA==\n	1398079213
session:865984efee0655008efef2fd5719c79a5e96113d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTQAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE0AAAACV9fdXBkYXRlZA==\n	1398079214
session:14d914af42dddcacc813881d5d2550955cc79402                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTQAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE0AAAACV9fdXBkYXRlZA==\n	1398079214
session:962cf7bfdc8153530bd4bad26b4330a7783d60a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE1AAAACV9fdXBkYXRlZA==\n	1398079215
session:dd811c539854fc72564007180c4650e5740aef47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE1AAAACV9fdXBkYXRlZA==\n	1398079215
session:b00740b37e58ccb6c6488d711338fa0248fb29e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE2AAAACV9fdXBkYXRlZA==\n	1398079215
session:85fdcdfb34ec4f1338bae138c044e3ac2bbda3de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079216
session:09e7a4d1c81dc6a88fdc581255b6b262a04e3ee9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079217
session:7d41a46689d183bc6357a646a3e8be7e0d003a3e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079217
session:688699eac78249dbf2fad7c6a4d2f5f97dbe97f5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE4AAAACV9fdXBkYXRlZA==\n	1398079218
session:fde2ab14c92731b5a184530eda18ab0a67e640aa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079218
session:f797c1d461f742bb00292b147c13d817610d7237                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079219
session:ed8d45bcaea80f0ffe4d08cee2234741b35ac9c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjAAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIwAAAACV9fdXBkYXRlZA==\n	1398079219
session:f2c9bf3b3500caa97f49cd5731026f80832a9477                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIxAAAACV9fdXBkYXRlZA==\n	1398079221
session:4336b05dbfcc2180c04a4b3467faa262c09b468d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIyAAAACV9fdXBkYXRlZA==\n	1398079221
session:f76c21fff1f58d08014e32d7eed060a59f2440dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIzAAAACV9fdXBkYXRlZA==\n	1398079223
session:10a4dab840f716d170e07d22c93478813d3bdfdc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIzAAAACV9fdXBkYXRlZA==\n	1398079223
session:795d793f43e909b0147858a7883ad01eb02adc3f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI1AAAACV9fdXBkYXRlZA==\n	1398079225
session:2b036a6d39ed85f4b665af29f9014e779d855034                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI2AAAACV9fdXBkYXRlZA==\n	1398079226
session:a74e5faf1d6ef464bdbba7e1735762679bb908dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI2AAAACV9fdXBkYXRlZA==\n	1398079226
session:23f67150a2155637d2c8ff1b5c66f403d211ee80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODEAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgxAAAACV9fdXBkYXRlZA==\n	1398802181
session:55f4af79a826b53769432985737eb567be04d7ee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODIAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgyAAAACV9fdXBkYXRlZA==\n	1398802182
session:57205ffbfa992004e71870dfd60169fad8c3ab6f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODIAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgyAAAACV9fdXBkYXRlZA==\n	1398802182
session:2838934e1ddb7b2cbac4084d4db55d6711f3465b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:8e4e86de6d77cd6f6cacf98a14e25372b5e96fee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:e8898497f2c432cf5275902d4758bc83b757e424                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:64f375f1500462c05b896d37170f0477c5797f30                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:709e6bdf96437bdf4201d0e5ee4d0391276a05c2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:d1a07aa842d5ddddc5bea718ab7461ed4f42d572                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:f55c4bd7166c9f3e141dab6d3632a8f8e88e79b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:10dd1ef57e360228fb6d3b2a368466f3643996d8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:25b731209530f7f11afad94b0babf1489807c1ab                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:a388a4d367daac9547c190e091018cb8e06b7b1b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:987d8a985a4fa5ba501a20a41294309e493568b5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:fe75e10fe6c1353fc7d563dd433328be47da4a9e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:a44a7fd7c167bd16db6d0ce5b3d53e1fe6258d14                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:0aed078782bdfd6e00359c7e3ad975c7d8aa620c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:a573e010ba0db876b116448a825dcf6ece7114a2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:c714366e3c694fec817669bb353f45a1fc375977                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTQAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE0AAAACV9fdXBkYXRlZA==\n	1398079214
session:f89d6043dcb65bebb8b59ceb83b0878a75bee2ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTQAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE1AAAACV9fdXBkYXRlZA==\n	1398079214
session:96829da5b6792169bc8c0f0e75cbec2638393186                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE1AAAACV9fdXBkYXRlZA==\n	1398079215
session:19c512f5889ac937b8b9c0a4ee372f9b20ee87d3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE1AAAACV9fdXBkYXRlZA==\n	1398079215
session:5b9358ac4f7fd9521fd330f15a5c72e849cee4e8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079216
session:1c479aecc4ed41222ddc172abd3be654cd5fc4b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079217
session:11fd171608b85b22b9fd7e55299ffd04f744cdbd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTcAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE3AAAACV9fdXBkYXRlZA==\n	1398079217
session:51748a703a2487d80dab8d444b94d2799adef98c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTgAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE4AAAACV9fdXBkYXRlZA==\n	1398079218
session:b31a06359b4977d5032745be8509fb2759bac455                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079218
session:7b787c3d4ec31567ea685e32ae8b81fa143e81af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079219
session:29ce16f06b48c2fde91aa7927afd83c613d66b8b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079219
session:087244d817ceff82952f6b9e2c45d0ccf065810e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMTkAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDE5AAAACV9fdXBkYXRlZA==\n	1398079219
session:6f6b88b6a6b8c716ec1be9ecae6f38aa3e0c8ce9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjAAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIwAAAACV9fdXBkYXRlZA==\n	1398079220
session:f32d1468e499334a14a69dd77e9027988f26f5b1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIxAAAACV9fdXBkYXRlZA==\n	1398079220
session:b94793e28d90b5170aa4a6b089d1ba467e2bba09                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjEAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIzAAAACV9fdXBkYXRlZA==\n	1398079221
session:3fd4a220572a9d38c3118a3455c402f4b88fc9bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIzAAAACV9fdXBkYXRlZA==\n	1398079223
session:7c0e6aa7db2d8465c417989a6d34a151676e8988                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjMAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDIzAAAACV9fdXBkYXRlZA==\n	1398079223
session:c8e8c2605750e2e272b86792c1f6487f983b7e8c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjUAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI1AAAACV9fdXBkYXRlZA==\n	1398079225
session:14ab4be91baf4de2ea28bf3ac8a890f3361492dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI2AAAACV9fdXBkYXRlZA==\n	1398079226
session:abd154c63d405734afeccfd99faeec0a79f303f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTU2NjAwMjYAAAAJX19jcmVhdGVkCgoxMzk1\nNjYwMDI2AAAACV9fdXBkYXRlZA==\n	1398079226
session:3ce272435e742c53b87f84764cdfed064536e073                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODIAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgyAAAACV9fdXBkYXRlZA==\n	1398802182
session:83e747c2efd24f93d679779798518e3efa8ed6f6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODIAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgyAAAACV9fdXBkYXRlZA==\n	1398802182
session:f5ac9eedee72ae778fb147e3da91e344b93f9b20                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODIAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgyAAAACV9fdXBkYXRlZA==\n	1398802182
session:23b6a9ffc96a2505d84d66bab6b666bb360420fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:b3b83a1642fcaa6b243c446e8727c11015590216                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:a256c98702f984e1627082b67d0339dd8b6f0ccf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:6f825c973bec33a5a712652a2db2d35c71ecf961                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:eaaf7d623ed407a53ef6835ac23e7d0dc2c7938a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:8beecb0e0325d8f4089588b015e8f63d4b8e669c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODMAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTgzAAAACV9fdXBkYXRlZA==\n	1398802183
session:e548892840a072ac3acf4f3320fe66390e6a7df5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:ece4f17893c0774c342b765b42ec86267279bba5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:3f26def8982bceb3ba937d3b45bb295d64382653                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:32cf99b4681519e4990c85c0ad8df6936e3d4df4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:db81e8ac5c23739c2b5c8f9b7b74f6a4b9d3fc9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:21bdaaa07e03ddea8151193bc23e0bcb6ca6cfc0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:945a705e9f1bdb6522a668663c493272d403350c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:04534b871f5bf9c813e009f29c012c6ae04148cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTYzODI5ODQAAAAJX19jcmVhdGVkCgoxMzk2\nMzgyOTg0AAAACV9fdXBkYXRlZA==\n	1398802184
session:6d86b8124eebd550cacb40c2d52792359113f3a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzUAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc1AAAACV9fdXBkYXRlZA==\n	1399448975
session:b568e77af6c84aad11f56eef1bc0492e28f242ef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzUAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc1AAAACV9fdXBkYXRlZA==\n	1399448975
session:0017d26ca70a2f5cc9d7dc4fcca3b87b19e806c2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA0AAAACV9fdXBkYXRlZA==\n	1399449304
session:b634e98778881b74efd6878ebc059864403d1406                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA2AAAACV9fdXBkYXRlZA==\n	1399449305
session:27146adf44a0b3c2f169510b131255df184cfc2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA3AAAACV9fdXBkYXRlZA==\n	1399449306
session:6f38ca964345603082c9a4c8633152c031f1ecc1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA4AAAACV9fdXBkYXRlZA==\n	1399449308
session:0790a1752084ccdfa2b0234b458b1a6d3ac43b8b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA5AAAACV9fdXBkYXRlZA==\n	1399449308
session:270fb51a1e53550a548a3965900ee352a8bf9d21                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA5AAAACV9fdXBkYXRlZA==\n	1399449309
session:4dcfc5bdea1ce1942f10d7f1f69735765dba342c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEwAAAACV9fdXBkYXRlZA==\n	1399449310
session:032072e64b209c039cbdef8610414adfab8bb42e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTExAAAACV9fdXBkYXRlZA==\n	1399449310
session:2163e3926e0fea1b8938d2e58c5ee94733e6f394                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTExAAAACV9fdXBkYXRlZA==\n	1399449311
session:9cd4d080384a47386c5e47fd76b0cf1f0b05a047                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEyAAAACV9fdXBkYXRlZA==\n	1399449312
session:cac68ff69cc7983af0d7f442ee0326b972ddca71                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTMAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEzAAAACV9fdXBkYXRlZA==\n	1399449313
session:ad90819a6a4631e7b4e5ceb6b5ea1d5a8c5a8935                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE0AAAACV9fdXBkYXRlZA==\n	1399449314
session:072aa897f33478e932d114e6fc31a84afe2f7a85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE1AAAACV9fdXBkYXRlZA==\n	1399449315
session:1369ff63a31bdef13222e3fcdf781237368bbe86                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE2AAAACV9fdXBkYXRlZA==\n	1399449316
session:a0b55bb12faf602f239e2819c212770939c64dcd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE3AAAACV9fdXBkYXRlZA==\n	1399449317
session:2f67ac5106b80bfb6f37fa2f44a073ebbf8eb5e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE5AAAACV9fdXBkYXRlZA==\n	1399449318
session:754ba8cdbb5b6c36119c579ba43091c8df64ce8e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE5AAAACV9fdXBkYXRlZA==\n	1399449319
session:602e3cec1cfb15e9117a77f1cea7c4e8c5130e1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIwAAAACV9fdXBkYXRlZA==\n	1399449320
session:a2aae2a1cbb4640026b57d6135ea0d8c54f64f28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIxAAAACV9fdXBkYXRlZA==\n	1399449321
session:b5b4f5ed456346640f6524d67acceeac5f1e7da3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIyAAAACV9fdXBkYXRlZA==\n	1399449322
session:74d1bdd2eb7eea381f456036b77e13229982a82a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjMAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIzAAAACV9fdXBkYXRlZA==\n	1399449323
session:764bd193ee7f83132fe04b6baeee4605f7d96202                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI0AAAACV9fdXBkYXRlZA==\n	1399449324
session:7402716ee3d5b40015350ae8c70e814ca9f37696                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI0AAAACV9fdXBkYXRlZA==\n	1399449324
session:42af6675cd9b79a3fc4f0d9852a7f5a3dddc0987                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI1AAAACV9fdXBkYXRlZA==\n	1399449325
session:a8664713ef729a2d0210dadbc3b23611356d254f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI1AAAACV9fdXBkYXRlZA==\n	1399449325
session:e8cbeff1f8f28885f92f854cc3ab578a8a4e94a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI2AAAACV9fdXBkYXRlZA==\n	1399449326
session:615e1e1b76cc1d1a7bc27a1d93b0d39099b02d8a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI2AAAACV9fdXBkYXRlZA==\n	1399449326
session:6920f75dbebd952c03663d09325923ae77b48c59                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI3AAAACV9fdXBkYXRlZA==\n	1399449327
session:dbe97cde3b2217d348b10c1d52becbe2095ffeba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI3AAAACV9fdXBkYXRlZA==\n	1399449327
session:d65d01f6190a7018915ce441b4c6b59cb42d423b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI3AAAACV9fdXBkYXRlZA==\n	1399449327
session:13585d24d2c89296db5d4e678b4e4c1491d1237c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI4AAAACV9fdXBkYXRlZA==\n	1399449328
session:ba0d913a7bbfd9c000dcab0a79e09150f5d25fbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI4AAAACV9fdXBkYXRlZA==\n	1399449328
session:87acf18be90d75d4db8eae85066faa11cb6c7068                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI5AAAACV9fdXBkYXRlZA==\n	1399449329
session:dde3a9a029bb06871252d967a716948ed47b4f9b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI5AAAACV9fdXBkYXRlZA==\n	1399449329
session:c29b7a200864bf4b9c177c2d6c1bf38ff1fa1c2e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMwAAAACV9fdXBkYXRlZA==\n	1399449330
session:5800c313a13e0a444ad84458fe05f0b5953d9111                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzUAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc1AAAACV9fdXBkYXRlZA==\n	1399448975
session:fc1a0f904cb01bd409227f83eacd3e1975d9afdd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMjk3NzUAAAAJX19jcmVhdGVkCgoxMzk3\nMDI5Nzc1AAAACV9fdXBkYXRlZA==\n	1399448975
session:4c348a7cb505262e42a544ba400d1079f98b3178                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA1AAAACV9fdXBkYXRlZA==\n	1399449304
session:8b80d24f6f33a8943ae6363b2c376df3eb9f9e6f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA2AAAACV9fdXBkYXRlZA==\n	1399449306
session:2b67cba9e2dc9634eccdb889335eab00a5ba79a6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA3AAAACV9fdXBkYXRlZA==\n	1399449307
session:caa91e42429e6e380a36e8e771bffb58de17acc3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA4AAAACV9fdXBkYXRlZA==\n	1399449308
session:bf7a7066e8f285cf5dbda043b8be725e0fa71ca3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA5AAAACV9fdXBkYXRlZA==\n	1399449309
session:fb819baf7909bcc133a4e57e1e2bb8ca3a91f202                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMDkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTA5AAAACV9fdXBkYXRlZA==\n	1399449309
session:c5a77c8432ecfa9e4318ce5a088bff715c3e7c01                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEwAAAACV9fdXBkYXRlZA==\n	1399449310
session:4061931e2334e391de87a28768a9a5ca97998842                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTExAAAACV9fdXBkYXRlZA==\n	1399449311
session:2823791c0c0a43d5ef8b103dba96a75b97f1634f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEyAAAACV9fdXBkYXRlZA==\n	1399449312
session:9838e46bf2d713c0f4e7b864c17799a111a12258                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTMAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTEzAAAACV9fdXBkYXRlZA==\n	1399449313
session:db35343c85366058ab6991c04a891e671f7fb891                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE0AAAACV9fdXBkYXRlZA==\n	1399449314
session:508f43e8bf2c6665f3c3f35c3d0c42b5f8a7f979                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE1AAAACV9fdXBkYXRlZA==\n	1399449315
session:1989343034d448daade8f60d70b4f69ef1e1e98e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE2AAAACV9fdXBkYXRlZA==\n	1399449316
session:648df6389004e5339b8a59a7e534a7e7bfed29db                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE2AAAACV9fdXBkYXRlZA==\n	1399449316
session:03ce406df4b4148e06e2bf1c2eee0a1631544962                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE4AAAACV9fdXBkYXRlZA==\n	1399449317
session:2cfa20305f84fb2ac3fdbfffcd37a626cd9f8f7e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMTkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTE5AAAACV9fdXBkYXRlZA==\n	1399449319
session:782d4f334c46de8307a0d73acb699529cf66abd0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIwAAAACV9fdXBkYXRlZA==\n	1399449320
session:de04b8003a1483a1a5e5dcd056c68d066b7a5fca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIxAAAACV9fdXBkYXRlZA==\n	1399449321
session:c1795c1a161ba21029cb3fdf09677dfd8e4756fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIyAAAACV9fdXBkYXRlZA==\n	1399449322
session:252c05113e0807b0a45c974b7e762ffeff570d94                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjMAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIzAAAACV9fdXBkYXRlZA==\n	1399449323
session:424b188f39df11c4a34ba571c236ab54486b7280                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjMAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTIzAAAACV9fdXBkYXRlZA==\n	1399449323
session:a559cafe9f5c3c435b9849890bb6d29ce722e56f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjQAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI0AAAACV9fdXBkYXRlZA==\n	1399449324
session:abf698ba9a78f05618bc23dcda936ee31688c1cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI1AAAACV9fdXBkYXRlZA==\n	1399449325
session:a778dee092981443948e35c4e9b06f99b69c5b42                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI1AAAACV9fdXBkYXRlZA==\n	1399449325
session:45c9520817d4d2162f42a85d2880a6aec2b7b940                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjUAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI1AAAACV9fdXBkYXRlZA==\n	1399449325
session:1bd1cfcaf0165277b9ce860a4c66dfbb81b36fa5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI2AAAACV9fdXBkYXRlZA==\n	1399449326
session:07df86aa247e1746b4e2fd98d7b5a46ed0ca4546                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjYAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI2AAAACV9fdXBkYXRlZA==\n	1399449326
session:7a950470001de3f4b5c3b84f92dc0f4b626e0491                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI3AAAACV9fdXBkYXRlZA==\n	1399449327
session:d73dc609dd7ee49822f79f90ebb5551da3fb0a8a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjcAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI3AAAACV9fdXBkYXRlZA==\n	1399449327
session:b1ecccbde4b37397d1579184ba12dc9e46048b2c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI4AAAACV9fdXBkYXRlZA==\n	1399449328
session:16475e7d3367569d01336f21f67ab282549bdad9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI4AAAACV9fdXBkYXRlZA==\n	1399449328
session:7e88cae43e8d7fc29788b913ef24dbe89547895b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjgAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI5AAAACV9fdXBkYXRlZA==\n	1399449328
session:20279fbb94eeae7b8bdcbf8890df028509f669bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI5AAAACV9fdXBkYXRlZA==\n	1399449329
session:fd21ad52541be10810a30e09cadbaf271f9996c1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMjkAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTI5AAAACV9fdXBkYXRlZA==\n	1399449329
session:ec82bedd1c6405b26a80a3fcffff0cc3288357b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMwAAAACV9fdXBkYXRlZA==\n	1399449330
session:bc33c55fa9686c470e765d64fa2fcdd2564744fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMwAAAACV9fdXBkYXRlZA==\n	1399449330
session:8aa1d76ecafc3ba153e82ec53b32d4b9d635bb90                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMwAAAACV9fdXBkYXRlZA==\n	1399449330
session:db824866257de3bedcfb5f7182b0f5176a07c4d9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMxAAAACV9fdXBkYXRlZA==\n	1399449331
session:6b888eab38621ceff47bd80e280f5a26cc7a3602                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMxAAAACV9fdXBkYXRlZA==\n	1399449331
session:a08ad88d2a2d33fc7b58ea34c74a504f0113404f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMyAAAACV9fdXBkYXRlZA==\n	1399449332
session:ecd6bc516bed2b748c4adeb3ad84c9975de8fe6e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMwAAAACV9fdXBkYXRlZA==\n	1399449330
session:242eab272515f672f63d680bab6dc9586225ab81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMxAAAACV9fdXBkYXRlZA==\n	1399449331
session:c71371a7e59e60ee6aa0037829b743fce9bd5e92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMxAAAACV9fdXBkYXRlZA==\n	1399449331
session:a184ac34cf3a9c587e8248179f70bcaa8b5d47a0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzEAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMxAAAACV9fdXBkYXRlZA==\n	1399449331
session:806e1531786d860633b36cb2896aa1ff9806463c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwMzAxMzIAAAAJX19jcmVhdGVkCgoxMzk3\nMDMwMTMyAAAACV9fdXBkYXRlZA==\n	1399449332
session:27873cc3db179f9d07337078ffa40b3a11e56af0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwNDI2NjMAAAAJX19jcmVhdGVkCgoxMzk3\nMDQyNjYzAAAACV9fdXBkYXRlZA==\n	1399461863
session:a2bab23184deb800964db4fc9e9ae23547845b1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwNTE0NTIAAAAJX19jcmVhdGVkCgoxMzk3\nMDUxNDUyAAAACV9fdXBkYXRlZA==\n	1399470652
session:fa0d4b064c9828dc381311196f89a55675084e1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwNjU2MDAAAAAJX19jcmVhdGVkCgoxMzk3\nMDY1NjAwAAAACV9fdXBkYXRlZA==\n	1399484800
session:2a0a6e9d4567c28a68aa2b45b13da1bcf54bfac0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwODc3NDgAAAAJX19jcmVhdGVkCgoxMzk3\nMDg3NzQ4AAAACV9fdXBkYXRlZA==\n	1399506948
session:6b3240168586892d165e19ddb0551911bd5df02c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTQyNTcAAAAJX19jcmVhdGVkCgoxMzk3\nMTE0MjU4AAAACV9fdXBkYXRlZA==\n	1399533457
session:66d1ee50afa44dce04e52eb3443c20a8b9fc63a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzgAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM4AAAACV9fdXBkYXRlZA==\n	1399534338
session:6d7f2f237f71d90c3df2a094ae276a11f5410403                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:c192c5f1c9394d207704e3539c8a40293df2bd31                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:9d74bf2c4e3b6a6809db8fa311bc56366180f2bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:bc53f4cbda214d8a05d2e4ec520a54afe79e1a05                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:18df0687ed0f6710675cb60a8499f3cdc2aba6c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:138397912a5394661f82b21ef6d8c0225140dc36                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:402881b15b9cdaa4e018e94b6f00912ee3f599eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:7634fa0005f3fd4060f6ccf111626bd07f94fad7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:20297960425ddb28ef099f519d5752aba28ea401                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:2085921586300c6c080383d6ae5eef4ed2c5bcbb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:6c23f8935885402fcf97beb26df505c30651da27                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:4872a81dc426ea09dc31e2cc9beae3e806df7cbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:9cd51431cd37414f55e12e3f9f0920303bcbff8b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:27577d62a7d0c6a3452e8f2998c80b3ea988930a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:8fe3be413877deed3144ec901079120402fd1503                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDQAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ0AAAACV9fdXBkYXRlZA==\n	1399534344
session:064dec148f808d6504a1e2172827f1522917d8e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDQAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ0AAAACV9fdXBkYXRlZA==\n	1399534344
session:ab3b29c16c823992b3198736a6627f17acef43f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDQAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ0AAAACV9fdXBkYXRlZA==\n	1399534344
session:07afc701f9e2e584ef56d830f6a64f6216053a7e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:58a4de108733a2fcd2b663b4b3ca150ff2c07277                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:1a247c06bc53fcf343c26ae8a8045578cf00ce2f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:571d078c6141348ddfcc456d3de4675c4389d1dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:f960f714bf68d1baf588f5f4c69b60a48ca6df40                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ2AAAACV9fdXBkYXRlZA==\n	1399534346
session:56c137b46dcadd6d4318a12a8c8208389ddd041b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ2AAAACV9fdXBkYXRlZA==\n	1399534346
session:610d29fd754e16595c33487af26aa7d4c0630639                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ2AAAACV9fdXBkYXRlZA==\n	1399534346
session:908f6e6b85a2feba296f75770bc0e76ec0d1ba1d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDcAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ3AAAACV9fdXBkYXRlZA==\n	1399534347
session:b91aeaeaf53e67447ddb591349ccebc6e5aebfe4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDcAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ3AAAACV9fdXBkYXRlZA==\n	1399534347
session:3166f1ae8f6fb17088aa0c5bf1f2ce2559110a7b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUwAAAACV9fdXBkYXRlZA==\n	1399534349
session:a88e2f935d92cc27b91356c74f1d3c6be9752836                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNTAAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUwAAAACV9fdXBkYXRlZA==\n	1399534350
session:88ff6ddd747015aee3ddff277ab0ecd3414ba324                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNTEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUxAAAACV9fdXBkYXRlZA==\n	1399534351
session:968686874708f4a45c90f5b4231ef080ca03893d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMzAzNDcAAAAJX19jcmVhdGVkCgoxMzk3\nMTMwMzQ3AAAACV9fdXBkYXRlZA==\n	1399549547
session:b78ce3d6192a372198c65903e47a34e99d9c91e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwNDM3NzMAAAAJX19jcmVhdGVkCgoxMzk3\nMDQzNzczAAAACV9fdXBkYXRlZA==\n	1399462973
session:6696b389d90693fd8b9896f3f50561fbe82f43c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwNjEwNzAAAAAJX19jcmVhdGVkCgoxMzk3\nMDYxMDcwAAAACV9fdXBkYXRlZA==\n	1399480270
session:11b09abf2b7777a52c7f1376d087d6135f054b3f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwODc3NDgAAAAJX19jcmVhdGVkCgoxMzk3\nMDg3NzQ4AAAACV9fdXBkYXRlZA==\n	1399506948
session:b9dc15998f99cf8cf0f78c2e20072788c327f10d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcwOTQwMDQAAAAJX19jcmVhdGVkCgoxMzk3\nMDk0MDA0AAAACV9fdXBkYXRlZA==\n	1399513204
session:c6894ecb84a100507cba7ff4263a5c69c27efbc3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzgAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM4AAAACV9fdXBkYXRlZA==\n	1399534338
session:2d7d61638e51a68671ca0a5463e95d206c3ea343                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:2f0d6f3690013e88b2d19c00fe30a7ebb71ac231                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:535ca30faef34e7dead4a35d371b49f1daa516bc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxMzkAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTM5AAAACV9fdXBkYXRlZA==\n	1399534339
session:a1a385d657fb209ee38ec89ab5c29c6d304f6a3f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:4f085c977be06b2941506b881a9ab52ce1d1d280                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:630945ad4983ba31c901d71f2f1461a87d794d8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:e7d2b0c10d31eb8e88bdb5083f961707162e8537                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQxAAAACV9fdXBkYXRlZA==\n	1399534341
session:8439b36918c93221f2cff67b997d23b50a1ab4cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:76ce7272fb9d34ba04ba0e9fe067b8b0b79ed918                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:55dfca8099c051c8814392acbb9ba6b1e868e083                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:ed73ed93bc420ebc2728efdf2c9e8a2176ed5258                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDIAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQyAAAACV9fdXBkYXRlZA==\n	1399534342
session:71875f6fe41c85790ea1ab4cfb968a237d2d64b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:d6829343d9c0997b063e6027c439776d05200702                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:7ccb518f574e148cf8ef576db0d60a63dd40e1bc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDMAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQzAAAACV9fdXBkYXRlZA==\n	1399534343
session:db22796972e702c9b94ff2755b4bf604438dc69b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDQAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ0AAAACV9fdXBkYXRlZA==\n	1399534344
session:b978539083a626f8645847684754d4932d0583c6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDQAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ0AAAACV9fdXBkYXRlZA==\n	1399534344
session:d618abc3578abcde522a433e84783a7130a64f83                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:efe293cf749c6ce9eba4d04a9957e086674e8327                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:69f7a488396d7d8197d83338b951f2b2860dfae2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:140dc44d21fd55abaf575d7d953d6bb7bf58374d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:356af9f15c214e69e8e09c049784b08525e709de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDUAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ1AAAACV9fdXBkYXRlZA==\n	1399534345
session:885f2ec0609619cc62d443b7b6a29a61db7362fa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ2AAAACV9fdXBkYXRlZA==\n	1399534346
session:7184bca4e4638c32903c00897d74a4eb7ed50470                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ2AAAACV9fdXBkYXRlZA==\n	1399534346
session:260287e6d2d38403131d2c6acda282124b5021e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDYAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ3AAAACV9fdXBkYXRlZA==\n	1399534346
session:c8ae44736dd39215274eb7fddc3b92d41d600f84                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDcAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ3AAAACV9fdXBkYXRlZA==\n	1399534347
session:e8e9b9747906b9e52f5cc8a783a48387de0c5f50                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNDcAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTQ3AAAACV9fdXBkYXRlZA==\n	1399534347
session:12040a41e7ae4331e9ddc23abdb146c0d9e0c324                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNTAAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUwAAAACV9fdXBkYXRlZA==\n	1399534350
session:8d130a67d9b85e3ce6e99ed0784a21a478d0dab9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNTEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUxAAAACV9fdXBkYXRlZA==\n	1399534351
session:e1744731b42d544e9c0add9f4797a24df8bc2fd4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMTUxNTEAAAAJX19jcmVhdGVkCgoxMzk3\nMTE1MTUxAAAACV9fdXBkYXRlZA==\n	1399534351
session:06e70009e3a7d3cd0d7d9a2d6446c60e72a9afd1                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5NDE5NDEyNgAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk3OTQ2NTk0AAAACV9fdXBkYXRlZA==\n	1401197912
session:dd575b5c370ab29a806ac1235846f2e770e889d3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1MjczNjgAAAAJX19jcmVhdGVkCgoxMzk3\nNTI3MzY4AAAACV9fdXBkYXRlZA==\n	1399946568
session:a41267279d11f67be27ab7ce8cd9cd021ab151e4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1Mjc1NDcAAAAJX19jcmVhdGVkCgoxMzk3\nNTI3NTQ3AAAACV9fdXBkYXRlZA==\n	1399946747
session:ac898ca037d29f5b05e5ca3622e847a2912b9c44                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA3OTcAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwNzk3AAAACV9fdXBkYXRlZA==\n	1399599997
session:d3eae78fd7b531ca9c04f410188093555c0c7122                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MTAAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODEwAAAACV9fdXBkYXRlZA==\n	1399600010
session:00a037afcdac04893443612cb56526fa23862b6b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MjUAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODI1AAAACV9fdXBkYXRlZA==\n	1399600025
session:ce7615661f163c000041574fbc5fead3a5a2ec89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MjYAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODI2AAAACV9fdXBkYXRlZA==\n	1399600026
session:1367cc89194a0f589f75de3c59d8705ddcb2b9ca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MzUAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODM1AAAACV9fdXBkYXRlZA==\n	1399600035
session:62efd10254652710391f6b814bfb8a3cfad3ee3e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODE2NjUAAAAJX19jcmVhdGVkCgoxMzk3\nMTgxNjY1AAAACV9fdXBkYXRlZA==\n	1399600865
session:2781da536da7375bf24b573c92994b237ca2e011                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyMTkzODgAAAAJX19jcmVhdGVkCgoxMzk3\nMjE5Mzg4AAAACV9fdXBkYXRlZA==\n	1399638588
session:58570ad87e6c9ed4b5bec75422afe645ddbc6b54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxMzg4NzEAAAAJX19jcmVhdGVkCgoxMzk3\nMTM4ODcxAAAACV9fdXBkYXRlZA==\n	1399642791
session:12bf2cf9f3c736d8be311bd8233ec63fafc6ced3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyODMwNTEAAAAJX19jcmVhdGVkCgoxMzk3\nMjgzMDUxAAAACV9fdXBkYXRlZA==\n	1399702251
session:87174f0ba3bf4c1f1caf0bdac0f7402b0993d9f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMjc2NjgAAAAJX19jcmVhdGVkCgoxMzk3\nMzI3NjY4AAAACV9fdXBkYXRlZA==\n	1399746868
session:5025c8d67dc2c00b395203214b8a4575fc61a2fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMjg5MDkAAAAJX19jcmVhdGVkCgoxMzk3\nMzI4OTA5AAAACV9fdXBkYXRlZA==\n	1399748109
session:40309e045a4cb027838128d17c6c5fe3bb08eee9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczNTU0MDYAAAAJX19jcmVhdGVkCgoxMzk3\nMzU1NDA2AAAACV9fdXBkYXRlZA==\n	1399774606
session:8cc8a7023f21a33183aed25c6446c47e1d0d2c79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczNjg5NzIAAAAJX19jcmVhdGVkCgoxMzk3\nMzY4OTcyAAAACV9fdXBkYXRlZA==\n	1399788172
session:e359a47d6d4f22872eb89e9091193a5c19f95a9e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczOTM1MjAAAAAJX19jcmVhdGVkCgoxMzk3\nMzkzNTIwAAAACV9fdXBkYXRlZA==\n	1399812720
session:46a85c12713c47e8b0db2f2414e6e6022d0488a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc0MzUyOTQAAAAJX19jcmVhdGVkCgoxMzk3\nNDM1Mjk0AAAACV9fdXBkYXRlZA==\n	1399854494
session:3b20714009db631bb3cf87a73538abc43ec724eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc0NDYwNDIAAAAJX19jcmVhdGVkCgoxMzk3\nNDQ2MDQyAAAACV9fdXBkYXRlZA==\n	1399865242
session:e45ab525d3759bd3688521590907a7127d87b5d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1NjQyMTkAAAAJX19jcmVhdGVkCgoxMzk3\nNTY0MjE5AAAACV9fdXBkYXRlZA==\n	1399984884
session:c91b028688e8fc838ad65d3cfeec4a335ca81815                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1NzU3MTcAAAAJX19jcmVhdGVkCgoxMzk3\nNTc1NzE3AAAACV9fdXBkYXRlZA==\n	1399994917
session:3bae4732e4346a02a9ea1742fff3c2e02b51c0a5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTQ0OTA5NTkAAAAJX19jcmVhdGVkCgoxMzk0\nNDkwOTU5AAAACV9fdXBkYXRlZA==\n	1402324059
session:021171a8f76a53ace57e7faee09ad6af4fe21b8a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MDkAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODA5AAAACV9fdXBkYXRlZA==\n	1399600009
session:a374d1fd49e0769163641ac9b9050f4dbea4b1be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MjIAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODIyAAAACV9fdXBkYXRlZA==\n	1399600022
session:82d0858e46b38d410c82c864b95fb765c8b2b819                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MjYAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODI2AAAACV9fdXBkYXRlZA==\n	1399600026
session:25763ee26d9dba6f4f00167e4c3b7aa966df976e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MjkAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODI5AAAACV9fdXBkYXRlZA==\n	1399600029
session:1eddafa0fe9bec0d180c8d291888c18f4dc8d592                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcxODA4MzYAAAAJX19jcmVhdGVkCgoxMzk3\nMTgwODM2AAAACV9fdXBkYXRlZA==\n	1399600036
session:d16fc4554805a56f968a33d3e4d7242f48b7fbf6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyMTEyMjAAAAAJX19jcmVhdGVkCgoxMzk3\nMjExMjIwAAAACV9fdXBkYXRlZA==\n	1399630420
session:8616a43cf1e91c0b1ffdd007de167966c79ef475                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyMjYzMDgAAAAJX19jcmVhdGVkCgoxMzk3\nMjI2MzA4AAAACV9fdXBkYXRlZA==\n	1399645561
session:8a3321cd95c5819a8284a7fd1a9e4604b6a087d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMjc1OTQAAAAJX19jcmVhdGVkCgoxMzk3\nMzI3NTk0AAAACV9fdXBkYXRlZA==\n	1399746794
session:bfb480ac0175b60dfab5ac6c4b9f332aa18e3088                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyMjYzODUAAAAJX19jcmVhdGVkCgoxMzk3\nMjI2Mzg1AAAACV9fdXBkYXRlZA==\n	1399645622
session:445f14d8eb2906fb75f64800d90a284117b8cf70                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMjc2NjkAAAAJX19jcmVhdGVkCgoxMzk3\nMzI3NjY5AAAACV9fdXBkYXRlZA==\n	1399746869
session:a1f82b0b5f64a8cb3582851b170323fa41dcbfe5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMzMyNTAAAAAJX19jcmVhdGVkCgoxMzk3\nMzMzMjUwAAAACV9fdXBkYXRlZA==\n	1399752450
session:7d4e67042b6b21abe24d24b8cd9f022543aab1bb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczNjY2OTYAAAAJX19jcmVhdGVkCgoxMzk3\nMzY2Njk2AAAACV9fdXBkYXRlZA==\n	1399785896
session:3d8d8e7823d11f9d1e5bf32c834a970ac8cee814                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczNzUyNjEAAAAJX19jcmVhdGVkCgoxMzk3\nMzc1MjYxAAAACV9fdXBkYXRlZA==\n	1399794461
session:3de1f9ab11cf1c276fbc5faf2c9c96cdf17c7c88                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc0MTYwNTIAAAAJX19jcmVhdGVkCgoxMzk3\nNDE2MDUyAAAACV9fdXBkYXRlZA==\n	1399835252
session:c71e4e5531f9fff717c4ef34efc2e064b2981a17                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc0MzU0NDQAAAAJX19jcmVhdGVkCgoxMzk3\nNDM1NDQ0AAAACV9fdXBkYXRlZA==\n	1399854644
session:06f27b54606edeea0d1e48243d8b9fff8e0cc796                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyNDIwOTMAAAAJX19jcmVhdGVkCgoxMzk3\nMjQyMDkzAAAACV9fdXBkYXRlZA==\n	1399661824
session:23a10703b1df9b61b3011d04aa3c9903eaa3295e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTcyODAxNjMAAAAJX19jcmVhdGVkCgoxMzk3\nMjgwMTYzAAAACV9fdXBkYXRlZA==\n	1399699363
session:22bbca8be420aff0950dafa5988542729eee94c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1MDE0NDUAAAAJX19jcmVhdGVkCgoxMzk3\nNTAxNDQ1AAAACV9fdXBkYXRlZA==\n	1399920645
session:af37915f537b459011370c7650c7c84df48725dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1Mjc0MjkAAAAJX19jcmVhdGVkCgoxMzk3\nNTI3NDI5AAAACV9fdXBkYXRlZA==\n	1399946629
session:ae3cbe644ec04526e01f5e7374f2f5d227da4856                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1NDk1MjgAAAAJX19jcmVhdGVkCgoxMzk3\nNTQ5NTI4AAAACV9fdXBkYXRlZA==\n	1399968728
session:c20aca1a5ac0f3ad1ef062ead36dc4d85e5cce82                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1ODQ3NTIAAAAJX19jcmVhdGVkCgoxMzk3\nNTg0NzUyAAAACV9fdXBkYXRlZA==\n	1401913849
session:b2b010320c98ccc285da0f25801c5c851d99a615                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTczMTg1MzIAAAAJX19jcmVhdGVkCgoxMzk3\nMzE4NTMyAAAACV9fdXBkYXRlZA==\n	1402414523
session:b4f9f80e0f21327e4874d44e7785b708b613bc45                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1ODgxMzQAAAAJX19jcmVhdGVkCgoxMzk3\nNTg4MTM0AAAACV9fdXBkYXRlZA==\n	1403989438
session:e114944409cf8c688a2776876215e081d2189471                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1ODQ5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nNTg3MjQ1AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1400006566
session:1ce7a4ca8fe10dd2bc5291df872380a6b4e0095d                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiCAAAAAmlkAAAABl9fdXNlcgoKMTM5NDEzNTA3OAAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk3NTg3Mzg0AAAACV9fdXBkYXRlZA==\n	1400006873
session:e3ac2822198b713505e9c696ffcc84fcb093c5ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDYAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA2AAAACV9fdXBkYXRlZA==\n	1400091706
session:a180e234cc09ceb0921aa4a3cb67632241710c16                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5NzU4ODU1MQAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk3NTg4NTUxAAAACV9fdXBkYXRlZA==\n	1400007765
session:7d8640dbc6b4c308cef7536a75dacaa6baee240d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA3AAAACV9fdXBkYXRlZA==\n	1400091707
session:ce127210abefe4746d774d5ee34e06ecb216b258                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA3AAAACV9fdXBkYXRlZA==\n	1400091707
session:599509b4767b4e559b60b4c2b6d93333288304ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1OTI3MjQAAAAJX19jcmVhdGVkCgoxMzk3\nNTkyNzI1AAAACV9fdXBkYXRlZA==\n	1400011925
session:086518cb8cf418b3f926e6f37b5cde3516bd31fc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA3AAAACV9fdXBkYXRlZA==\n	1400091707
session:9aaf7d5ec8b0bbe76be127dcd65bec79fdde3201                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1OTI3NzEAAAAJX19jcmVhdGVkCgoxMzk3\nNTkyNzcxAAAACV9fdXBkYXRlZA==\n	1400011972
session:bc3217490aa16c62ced573fad871249f4596f1b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDgAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA4AAAACV9fdXBkYXRlZA==\n	1400091708
session:3d6beaf09c99bc36bda8155cdf17602076dfbe6e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDgAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA4AAAACV9fdXBkYXRlZA==\n	1400091708
session:2d43a6be3ecab5bb6c94a022fda4c9e043b50c34                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc3MDYyMDgAAAAJX19jcmVhdGVkCgoxMzk3\nNzA2MjA4AAAACV9fdXBkYXRlZA==\n	1400125408
session:e2f6986f5c1ab7c8b491110fa5ac086714a15ec4                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc3NjI3MzMAAAAJX19jcmVhdGVkCgoxMzk4\nNjk1ODM5AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1401118620
session:467e18d391177e3f300133b0410e8f4075769e1a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1OTcwMzkAAAAJX19jcmVhdGVkCgoxMzk3\nNTk3MDM5AAAACV9fdXBkYXRlZA==\n	1400016317
session:60404815bd8fc3818d3690a2bbf1c6f3738755f9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MTgwNTUAAAAJX19jcmVhdGVkCgoxMzk3\nNjE4MDU1AAAACV9fdXBkYXRlZA==\n	1400037254
session:d3c22e6e435d79d53f1a6bd4c68f3b61d08504d9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:210f17d699edafc503f3934fdbe3eb423aefeaee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:b490ffa9d3e83bf8c49fcc4d390eb1132e768b9b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:112b72259d2b305af7b21bfd49b79d23a94ad55a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NDQ0NTAAAAAJX19jcmVhdGVkCgoxMzk3\nNjQ0NDUwAAAACV9fdXBkYXRlZA==\n	1400063650
session:44265b3e137a5a9ebe86140c61eaf4ba18d6cce4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NDYzMzgAAAAJX19jcmVhdGVkCgoxMzk3\nNjQ2MzM4AAAACV9fdXBkYXRlZA==\n	1400065538
session:25957cd56f2e6e314a4eb1fc784542476a04c1c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MDczODkAAAAJX19jcmVhdGVkCgoxMzk3\nODA3Mzg5AAAACV9fdXBkYXRlZA==\n	1400226590
session:1babd652a4fb3b65c664fcce304e9be1180f8e0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTcwNDUAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MDQ1AAAACV9fdXBkYXRlZA==\n	1400236245
session:5d99c1448206d34a5644d2d4fa990985902cb09d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTcwNDUAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MDQ1AAAACV9fdXBkYXRlZA==\n	1400236245
session:d7e0444c5e6320d60894b98393dcbf5c28a4296d                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwoK\nMTM5NzU4ODgwNQAAAAlfX2NyZWF0ZWQEAwAAAAEIiQAAAAJpZAAAAAZfX3VzZXIKCjEzOTkzMjU0\nNzgAAAAJX191cGRhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1401749454
session:88bdd3cb43313c03cbd6814468c448ecca4150b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc3NTAwNzgAAAAJX19jcmVhdGVkCgoxMzk3\nNzUwMDc4AAAACV9fdXBkYXRlZA==\n	1406222204
session:d972c6f2d9233b11065b03fdf2e28bc3a8524516                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc1OTIxNTgAAAAJX19jcmVhdGVkCgoxMzk3\nNTkyMTU4AAAACV9fdXBkYXRlZA==\n	1400011358
session:66298c4096f0f62faf41cd6fcc243f78e2254ca6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:6fd2423db15eb0e3a35ec8299d1af232ee05a5de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:610f78a9aad38add57df6c25ccb901fadd9223cc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2MjA0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nNjIwNDM3AAAACV9fdXBkYXRlZA==\n	1400039637
session:aaed163173bd5af8aafb16334ead2845cf7c176c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NDQ0NDQAAAAJX19jcmVhdGVkCgoxMzk3\nNjQ0NDQ0AAAACV9fdXBkYXRlZA==\n	1400063644
session:5ee68739cf7f2f9f77f367c1fc5e5cae693d40f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NDUxMDMAAAAJX19jcmVhdGVkCgoxMzk3\nNjQ1MTAzAAAACV9fdXBkYXRlZA==\n	1400064303
session:cca93d844df796e89aaf600d2779f24f6c27ede5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzA0OTcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcwNDk3AAAACV9fdXBkYXRlZA==\n	1400089697
session:5d9f05ba203330307e9f9ae385df0b8599664db7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDYAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA2AAAACV9fdXBkYXRlZA==\n	1400091706
session:81bc197020eb671282aefb81e0de402931c1e336                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA3AAAACV9fdXBkYXRlZA==\n	1400091707
session:06afa784f98eb71ac6cbb1b93c23793c2e0bc1a6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDcAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA3AAAACV9fdXBkYXRlZA==\n	1400091707
session:ad8152ca4ea83182210f055b99e6c1db65a10d12                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDgAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA4AAAACV9fdXBkYXRlZA==\n	1400091708
session:ec3de44202c18cc5ff4acec36290ccddeb268ec3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2NzI1MDgAAAAJX19jcmVhdGVkCgoxMzk3\nNjcyNTA4AAAACV9fdXBkYXRlZA==\n	1400091708
session:55e84a39f20d397fd66a6a0cc0689d0fb28d86be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc2ODIyNDQAAAAJX19jcmVhdGVkCgoxMzk3\nNjgyMjQ0AAAACV9fdXBkYXRlZA==\n	1400101444
session:2dfb3173643bdbcef9d95788d8829163b91ee2b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc3MjA5OTgAAAAJX19jcmVhdGVkCgoxMzk3\nNzIwOTk4AAAACV9fdXBkYXRlZA==\n	1400140198
session:c34e691207a65a6658b790cc241e9614360ab3f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc3NTI5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nNzUyOTY1AAAACV9fdXBkYXRlZA==\n	1400172165
session:b12c319383789b639e00813b4e496e3e7079904f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTcwNDQAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MDQ0AAAACV9fdXBkYXRlZA==\n	1400236244
session:f2bbf1265a611488058daf8854ea5ca43986d26d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTcwNDUAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MDQ1AAAACV9fdXBkYXRlZA==\n	1400236245
session:33ba1fb9b8f5dfd778dab205884383b7c6616af6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTcwNDYAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MDQ2AAAACV9fdXBkYXRlZA==\n	1400236246
session:7803cea23ed205086af2b259dd71a73c56f0939f                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5NzU5Mjk3MAAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk4MDg2MTY0AAAACV9fdXBkYXRlZA==\n	1400505367
session:1837d56364c11ede6e5a0094b6bed36571272d27                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTczMTAAAAAJX19jcmVhdGVkCgoxMzk3\nODE3MzExAAAACV9fdXBkYXRlZA==\n	1400236510
session:536418975f5a9f349b08bada8442cd6e38a0bf41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MjE0ODEAAAAJX19jcmVhdGVkCgoxMzk3\nODIxNDgxAAAACV9fdXBkYXRlZA==\n	1400240681
session:3d5bcc1b149312875559d4def6859df9b8127a2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ1AAAACV9fdXBkYXRlZA==\n	1400268145
session:457d33d04108c5e4d3152573c0b23556712d7f78                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:058ce1d88a99562ce25a35bdc5ab59c5fd65772b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:381cbd30bfb6df22a5043dd3cef5b78129626fa8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:636fafb2a1b48bae2a69f6f04ecfea270ceb6c62                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:fecc5c1e4825f0afcdfe6a829cb0b35a98742501                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:aa881d6b615a86ae8ea0bb05e1d74371f26c7391                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:938bfcfa31db24248683cb6be77dc044de98a91f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:5d50a2140e3e0b0c450159c91741ef17f8a05e4a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:9f142a0fdd062d00a45f080e722e81ee09ff2538                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:a64de335c72957fdcb75b4c45f3ca4a92929bcbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:008354a52a10bfaa7b314a924427b4aa465007ea                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:1e441d5c64f84db62962f7ab081f219b9a8f65f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:96e0348e15f6990f00134701c3b28bd9ea01f726                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:5f946f5c8a0d342e3a4d826ca99642a9a7d99c96                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUxAAAACV9fdXBkYXRlZA==\n	1400268151
session:3b74e21c7617f6e8ac51e5d853bf7483d53b881b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:426a98100d8b335a0f5ddb8282980cc09a440c95                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:c7123f8ad49938674afd34906e636d0dfb5fe16c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:e2eb4ad89cb78f7ce1b522585677e4e605a1ae47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUzAAAACV9fdXBkYXRlZA==\n	1400268153
session:c65cef9c8813df6ca916451501ddf01c658bd3ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUzAAAACV9fdXBkYXRlZA==\n	1400268153
session:fc87994262b37a96bf6ec25f292df0baf0a86204                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUzAAAACV9fdXBkYXRlZA==\n	1400268153
session:9351b3a0ad3e0dee9af45bce931955696f860c71                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU1AAAACV9fdXBkYXRlZA==\n	1400268155
session:54bc611fa88aa6b93afdf47f79adbb4754bc0067                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU2AAAACV9fdXBkYXRlZA==\n	1400268156
session:ebfc69218bfef801a1448a760b1b622d640f897e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU2AAAACV9fdXBkYXRlZA==\n	1400268156
session:0083a1267f9ea4ea41c6001eb83332d5db32d945                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268156
session:f5681efe72364e7162a0e0d390cdc079b0a79025                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268158
session:3fa8c05005b61a6580f82ac67a8d20f1de7c5c85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268158
session:c220bf9d70ceb425bcbd67cd3549d6e445b30394                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268158
session:27027a72b43b8192e792107a7c142fcf0341a662                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268159
session:7f896618868cb6be52b03e42102324620f189b55                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268159
session:57e78d11543b14f5243a3d6c0f2c6530751b9999                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYwAAAACV9fdXBkYXRlZA==\n	1400268160
session:5fdc1e42f2f23853cc6ee037916bb4d6bb27b825                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYxAAAACV9fdXBkYXRlZA==\n	1400268161
session:4889a9f5e9dc1b6c9d8b7ff7da6b01b317a9a5b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYxAAAACV9fdXBkYXRlZA==\n	1400268161
session:d26d37543bed2815a35ce7053b29f41991dccd7e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYxAAAACV9fdXBkYXRlZA==\n	1400268161
session:8a8a9508afc9dbde172b9e160bc9c0ea28446c2e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:bf579fe7f5cb153220fbd8850efb4b8423ef2afd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MTg3NzYAAAAJX19jcmVhdGVkCgoxMzk3\nODE4Nzc2AAAACV9fdXBkYXRlZA==\n	1400237976
session:2cc3ebb93082a5a242a011a8356e67fa9958531e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4MzU5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODM1OTYzAAAACV9fdXBkYXRlZA==\n	1400255163
session:7ed2c1764e1266821107b93b4d976b9e60e0d294                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ1AAAACV9fdXBkYXRlZA==\n	1400268145
session:8b3889833d44805c490db119ac145a5361e8998d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:3ae32f4209922c071777842e2e326732e224d0cc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:fbc3935defa86ac54c2d746cf3c9cc01d94bf57d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ2AAAACV9fdXBkYXRlZA==\n	1400268146
session:973679460d9b5b089d0ea51b0277459f46efd768                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:37589fba17ba210c55a658cddb9fe56717045ce1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:ba0a88e324d43b9aa6664e592617839f43c9e019                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ4AAAACV9fdXBkYXRlZA==\n	1400268148
session:c13233dc6c3a44e7a8b06a0fd78e5afe2b3cc5cc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:f195ffabc960c1d4fab463c7cdbbe181c9a94535                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:aca06c26b6a81a199b6fc40915cfc5265d5ce534                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NDkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTQ5AAAACV9fdXBkYXRlZA==\n	1400268149
session:6d81753db1a5dd3ec69b4006fc6b4fa152b10acb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:720e5c6c17a536931541e7e93c6617c4248e1035                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:d6b88bcdf54bae121149477db43e9e464d20bc06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:61078460ac13ce9eaa1511c44b8817820a78a016                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUwAAAACV9fdXBkYXRlZA==\n	1400268150
session:5045ed18718804a410b362e792d10d98ba73f241                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUxAAAACV9fdXBkYXRlZA==\n	1400268151
session:28b1d660c0f787d7b0162a52cde2b7c5abb97d58                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:962a062355f3371cac9abd98a0695e50687e3767                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:9594696d0b536c27519e544c9fed468f07d40c06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:edc6a026e365e23a1ece723c59381cd1cc287866                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUyAAAACV9fdXBkYXRlZA==\n	1400268152
session:4bcf96f430725f57b673878a551bea4cd4aea92c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUzAAAACV9fdXBkYXRlZA==\n	1400268153
session:41b230285d137b9482f4c3e94be0cdbd76f9ecea                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTUzAAAACV9fdXBkYXRlZA==\n	1400268153
session:33aa837eec1c18f09df93c1b300eda5836d77210                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU1AAAACV9fdXBkYXRlZA==\n	1400268155
session:936db70975c706075d87cad9d24a5f8cc59f45ca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU1AAAACV9fdXBkYXRlZA==\n	1400268155
session:94ddf42514facf281887314f89babd1acc7a07f0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU2AAAACV9fdXBkYXRlZA==\n	1400268156
session:70f8e6c2b8297f1e7a2aa8955e5e3789b7ed9e1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268156
session:0f74528546bc5021b6b64198f1edeae6b252acc4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268158
session:80513c911e6d554c733400198779b3a6defc81cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU4AAAACV9fdXBkYXRlZA==\n	1400268158
session:71eabc9bbc515fe4757774af38463b3926d40a0c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268159
session:f69a504895abfeac24384f0eb8e60d7b41326c25                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268159
session:a25ccc1f9eedddaddb58fdc706548cdb1a31d079                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NTkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTU5AAAACV9fdXBkYXRlZA==\n	1400268159
session:55ce14ad4fe71a4361dccf4d187d0f21458f4e40                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYwAAAACV9fdXBkYXRlZA==\n	1400268160
session:caf9be78eb8a89d1f694a46ca6ab7d31a2aeed41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYxAAAACV9fdXBkYXRlZA==\n	1400268161
session:74a820a61b66cdb2eb84de2266bb2405c1b04528                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjEAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYxAAAACV9fdXBkYXRlZA==\n	1400268161
session:3541aba8bf04dfdc5b21f940ec822a8129b35e34                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:1dbdd5d6999303f48e662d09a3ad589138abff32                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:7ecbc548c7771ed68cea45c9cb686bd715a1c8e3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:3817f51b0524792d909651879ea924db1e2a4aa5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:c747d598923495d89d222237685f39c8f2bcad0f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:644849a3d7186aa848786d89321f203ca0511c97                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:c5241ac50a1e21c044fea3070926f5efe69a3b9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:032341b51f808bcc1a618a76e761bfe6f7966a63                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:1e9a74c11ac9adfdb7dc8a2e20fddd79a5ae3a3a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:c561e4f361730bcc653eed9116bd4d7529cc6caa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:c9ec32803b5c3f251d69597566317d3652b3378f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:4d6261351c8859066b22121918f35980c9e7b7c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY1AAAACV9fdXBkYXRlZA==\n	1400268165
session:9df435616e675305329cd898e5e7e7cde82a4a0c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY1AAAACV9fdXBkYXRlZA==\n	1400268165
session:89ac3c7a64e89cc589a0c590953fe69bcb08c530                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY1AAAACV9fdXBkYXRlZA==\n	1400268165
session:4b37bbc3c75d49aa73c62ca9020c09cfbe0fe325                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY2AAAACV9fdXBkYXRlZA==\n	1400268166
session:85cb13e6d2b5c8c02cbb0e78c708ef69cce4719b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY2AAAACV9fdXBkYXRlZA==\n	1400268166
session:6052c7a46698cd9edd90821b9e8a39f338ec5b53                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:cff2c59284c809d37db61558ef25b66d1c9b0b38                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:cba2c2bf265f9280ed4acab3f8c20af72fb75882                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:48e6e16cb95aa1fff80ac644923fd167cdb73bf0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:cab375325c76cc251d71ad19650bef14276a4352                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:995690a496eaac43842840ecb440c41aab29a79f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:0d7e8157862f2b4dbc7380a1c701d2994bd76f0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:f2500f409760675d80a3b34b2c1077aed3494cd1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:89682fc6c9d8dad451959dd000cdadc03b6aa2c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:b6f185c56bddbaf69d15a016ba83fc4cdda411bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:80e82084035cde29a0816977e750cd46e34d549b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:ed83b148f0befd6f6780bd6c1a48aa974f1e3357                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:6cb1ff7c8fb9d5628dd7ca3771f5c72bf7657617                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTcwAAAACV9fdXBkYXRlZA==\n	1400268170
session:ba1dde3e491201169ee9b5a1f71b25e0c6e98d31                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:3877753dd1cced5c0359054331e5648dcb4077ee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjIAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYyAAAACV9fdXBkYXRlZA==\n	1400268162
session:73bae277e0186e5dddfac2a38ee6ce58171dd9fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:07b331d0a715848543391d41117f208a6d0eedcd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTYzAAAACV9fdXBkYXRlZA==\n	1400268163
session:ccd1005a842532b880b432dc74857c594a098ee5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:4596e0929970b50eb10ab7495a9d840fc754ce98                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:f7d4e52b4b6165acc79e6832bfc73f79b1544d75                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY0AAAACV9fdXBkYXRlZA==\n	1400268164
session:b3e66e2ef845f9cc235b761d7c909222886401a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY1AAAACV9fdXBkYXRlZA==\n	1400268165
session:98a34d19ec1cbe5b591a6147c6ee2204ffca43a2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjUAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY1AAAACV9fdXBkYXRlZA==\n	1400268165
session:57cb0725a9f70a7f7b9bef4624d3c5dff59b31f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY2AAAACV9fdXBkYXRlZA==\n	1400268166
session:a817daea0e15d42e020b8d44ba6b03471236b6ed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY2AAAACV9fdXBkYXRlZA==\n	1400268166
session:e51734a03b7b1f55b78fa79bbdb9ef331a76cb67                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjYAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268166
session:484d59ffa3935e72197f42c6093432c8c0a5b72b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:1ce9a9cbceb96d3420da0b46c07fcc1b3b6f1880                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:77ffc3e09ef1b296e275bf08940abcb9c68d9265                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjcAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY3AAAACV9fdXBkYXRlZA==\n	1400268167
session:8a88c3ca2c893fb9101ba6c50e771a35e5dcbc50                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:541d220359d8e0886be759846e5b75237ccbc810                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:66d56db25e654e07e3359834b1f08b530a776f21                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:8505254345acc720c1fb8463772502af9a3912b1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY4AAAACV9fdXBkYXRlZA==\n	1400268168
session:a5a48d5cba901bfb038345a912b3a14f81e2ca79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjgAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268168
session:375e8077a0e9bc4f6bdca57e5e176d393da0d28f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:f1a90f11df56d0f79625890cdd9ccee639d75c58                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:de7153c377ac398607c353be352faa5def09aabf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:04607ab398e8cecf0125709b870d741b8cfbefbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NjkAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTY5AAAACV9fdXBkYXRlZA==\n	1400268169
session:9077cc216ef584a4897b8df4236c1054b74dfa2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTcwAAAACV9fdXBkYXRlZA==\n	1400268170
session:281190ae304cef2d5c3d0cc1c7e0323152ff6fbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzAAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTcwAAAACV9fdXBkYXRlZA==\n	1400268170
session:cfa364d786721324e7f2c67d8f5d6e387ba423ea                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268173
session:31e6a9ab6338aabf9eac3b455ce50cdd101998e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268174
session:6b47c36145f6f51defe76c9590039b78714c6da0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268174
session:eaba5fc46c337dd9c4f38e1c5b63f9ae2d47018b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NzQ1OTkAAAAJX19jcmVhdGVkCgoxMzk3\nODc0NTk5AAAACV9fdXBkYXRlZA==\n	1400293799
session:236a28378d58a925a0d2469c3698ca797c83d058                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4ODYzMDcAAAAJX19jcmVhdGVkCgoxMzk3\nODg2MzA3AAAACV9fdXBkYXRlZA==\n	1400305507
session:fa9525074ab634968225040a77f28e807d5b5f1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc5Mzc0MzcAAAAJX19jcmVhdGVkCgoxMzk3\nOTM3NDM3AAAACV9fdXBkYXRlZA==\n	1400356637
session:330ddd9121cd03e96069570e03e61189e0333bb7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgwMTg2MTkAAAAJX19jcmVhdGVkCgoxMzk4\nMDE4NjE5AAAACV9fdXBkYXRlZA==\n	1400437818
session:8ca42f0c34a157e84182a7e5b6dd9d75bb880e74                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc5NDcwNTEAAAAJX19jcmVhdGVkCgoxMzk3\nOTQ3MDUxAAAACV9fdXBkYXRlZA==\n	1400941572
session:7b5ffcd8409a334177d5c477481d4c3034d5a951                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc5NTE0ODgAAAAJX19jcmVhdGVkCgoxMzk3\nOTUxNDg4AAAACV9fdXBkYXRlZA==\n	1402784534
session:de94ba8ee18cbe60503065cff1aa61846fc4c19e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzMAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268173
session:561b65447305c719d7a2debf7cb1203cf8acca43                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268174
session:0852d331c3d3e24ffc181a812a26cab39692db5a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4NDg5NzQAAAAJX19jcmVhdGVkCgoxMzk3\nODQ4OTc0AAAACV9fdXBkYXRlZA==\n	1400268174
session:f98a9e2708779dce0e685dc22f135a584b4a77ff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc4ODAyMTEAAAAJX19jcmVhdGVkCgoxMzk3\nODgwMjExAAAACV9fdXBkYXRlZA==\n	1400299411
session:d449ae3e98a14dc374dfea01657a9714d3e9a7fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc5MjY2NjEAAAAJX19jcmVhdGVkCgoxMzk3\nOTI2NjYxAAAACV9fdXBkYXRlZA==\n	1400345861
session:9e3d32678ed51f19c77e6bb8741fef1423576d32                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTc5ODE1NDIAAAAJX19jcmVhdGVkCgoxMzk3\nOTgxNTQyAAAACV9fdXBkYXRlZA==\n	1400400742
session:c8b1404cebd439385faaf037f535fabcc5876809                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgwMzE2OTQAAAAJX19jcmVhdGVkCgoxMzk4\nMDMxNjk0AAAACV9fdXBkYXRlZA==\n	1400450894
session:0fc516d10f8642c75632efdac365a150ce840cd7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgwOTg3OTcAAAAJX19jcmVhdGVkCgoxMzk4\nMDk4Nzk3AAAACV9fdXBkYXRlZA==\n	1400517997
session:b96c30b092a87a98cb478ec679cf468b9c1b280b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTQAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU0AAAACV9fdXBkYXRlZA==\n	1400527954
session:284c1faea77b1ed20c8cf0601234224593c7caf0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTQAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU0AAAACV9fdXBkYXRlZA==\n	1400527954
session:6f9a8511c223f0fca6a6661e27fe9e51de32e300                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTUAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU1AAAACV9fdXBkYXRlZA==\n	1400527955
session:7e533afe17a7ab3272a1ec0425b53c5d1fd40868                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMzc0NTkAAAAJX19jcmVhdGVkCgoxMzk4\nMTM3NDU5AAAACV9fdXBkYXRlZA==\n	1400556659
session:2d86f33b870dc1d53759683c04582713632cebaa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxNDk5MjUAAAAJX19jcmVhdGVkCgoxMzk4\nMTQ5OTI2AAAACV9fdXBkYXRlZA==\n	1400569125
session:e5cdf06a5cb0a37223b670099bfe5325ba950f09                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiBAAAAAmlkAAAABl9fdXNlcgoKMTM5ODE3OTI1NgAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk5NDk4NjcyAAAACV9fdXBkYXRlZA==\n	1401918022
session:0dbaa503903ba70bca01dbfd4bdcc4965b9c15ca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzNjI1OTEAAAAJX19jcmVhdGVkCgoxMzk4\nMzYyNTkxAAAACV9fdXBkYXRlZA==\n	1404310694
session:6142bff4c6be17cbfaae715ef3669c17c299b944                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTM0NTcAAAAJX19jcmVhdGVkCgoxMzk4\nMjUzNDU3AAAACV9fdXBkYXRlZA==\n	1400672657
session:e2f10e94ffc7b1d1e27a323ee7f9cfcfb9e092d7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTM0NTcAAAAJX19jcmVhdGVkCgoxMzk4\nMjUzNDU3AAAACV9fdXBkYXRlZA==\n	1400672657
session:88175547913b468357acb249b14e7561c0d6e5be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTQ1NjUAAAAJX19jcmVhdGVkCgoxMzk4\nMjU0NTY1AAAACV9fdXBkYXRlZA==\n	1400673765
session:bb7d4d25634cb822bef33fe18c684731be01d394                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTU5NjQAAAAJX19jcmVhdGVkCgoxMzk4\nMjU1OTY0AAAACV9fdXBkYXRlZA==\n	1400675164
session:0036778c1058a6c20554e20815b84fb91762c9ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyOTk4MjEAAAAJX19jcmVhdGVkCgoxMzk4\nMjk5ODIxAAAACV9fdXBkYXRlZA==\n	1400719021
session:c26b64fe3a4944562da6eea233b6039cd43eacc1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyOTk4MjIAAAAJX19jcmVhdGVkCgoxMzk4\nMjk5ODIyAAAACV9fdXBkYXRlZA==\n	1400719022
session:557c9ff6fab1947df5511d9cfb6d5f9a5e910eff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzMjkzOTUAAAAJX19jcmVhdGVkCgoxMzk4\nMzI5Mzk1AAAACV9fdXBkYXRlZA==\n	1400748595
session:35ed5a8a126522148d83e23fb41a1bbfbf9b0bc3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDE3NDYAAAAJX19jcmVhdGVkCgoxMzk4\nMTAxNzQ2AAAACV9fdXBkYXRlZA==\n	1400520946
session:574a25f26431da5e3fc572e57d65b998e27e1d29                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTQAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU0AAAACV9fdXBkYXRlZA==\n	1400527954
session:1f6ecea70c71c780a0b5c84aac47d82836234d74                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTUAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU1AAAACV9fdXBkYXRlZA==\n	1400527955
session:2f18d844b2837d479c7091044d26af4cc1e0aa33                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxMDg3NTYAAAAJX19jcmVhdGVkCgoxMzk4\nMTA4NzU2AAAACV9fdXBkYXRlZA==\n	1400527956
session:dcf4869a02f0581df2991ca2a54490c5c4132cfb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxNDU2MjUAAAAJX19jcmVhdGVkCgoxMzk4\nMTQ1NjI1AAAACV9fdXBkYXRlZA==\n	1400564825
session:b24fbced10bc35c5f3658931ad8986b21d457a06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgxNzAzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nMTcwMzI3AAAACV9fdXBkYXRlZA==\n	1400589527
session:3bdc5d49f93d8f759d5b8315abcec92a8ce1da65                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTM0NTcAAAAJX19jcmVhdGVkCgoxMzk4\nMjUzNDU3AAAACV9fdXBkYXRlZA==\n	1400672657
session:32e60b981849b5df100d9d03e1f069453d5aa013                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTM4ODgAAAAJX19jcmVhdGVkCgoxMzk4\nMjUzODg4AAAACV9fdXBkYXRlZA==\n	1400673088
session:06fc497e6f8066dd18a5733161ff6401a9e88225                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTU5NTkAAAAJX19jcmVhdGVkCgoxMzk4\nMjU1OTU5AAAACV9fdXBkYXRlZA==\n	1400675159
session:133b626480760789550d3cdf531daf40bf97c45e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyNTcxMzcAAAAJX19jcmVhdGVkCgoxMzk4\nMjU3MTM3AAAACV9fdXBkYXRlZA==\n	1400676337
session:ef4a58625483b0154032b69e4a3edfcae105b1c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgyOTk4MjEAAAAJX19jcmVhdGVkCgoxMzk4\nMjk5ODIxAAAACV9fdXBkYXRlZA==\n	1400719021
session:5626256ab1e78bb905116545c155a7766a3d3a71                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzMjQ4MDAAAAAJX19jcmVhdGVkCgoxMzk4\nMzI0ODAwAAAACV9fdXBkYXRlZA==\n	1400744000
session:ce836c7fc1072f646f53cdc591fc7ff9b3e0c701                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzMzA2MDAAAAAJX19jcmVhdGVkCgoxMzk4\nMzMwNjAwAAAACV9fdXBkYXRlZA==\n	1400749800
session:a00faa0fbea1034119c2bf27db3456e6d91c6bb1                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzNjc5OTgAAAAJX19jcmVhdGVkCgoxMzk5\nNTkwMTc3AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1402507430
session:5a1857bff4a45eb82881ae838c33539364b81d43                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzNTAxOTYAAAAJX19jcmVhdGVkCgoxMzk4\nMzUwMTk2AAAACV9fdXBkYXRlZA==\n	1400769397
session:4930853e1a4e6c8721cc3847d9bab814023e83af                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiIAAAAAmlkAAAABl9fdXNlcgoKMTM5ODM0OTk1OAAAAAlfX2NyZWF0ZWQIgAAAABBfX2Nv\nb2tpZV9leHBpcmVzCgoxMzk5NjY2MzQwAAAACV9fdXBkYXRlZA==\n	1402507547
session:30cd5fa0c4707ae832ee65efc306ee6636b9395e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzNTE3OTgAAAAJX19jcmVhdGVkCgoxMzk4\nMzUxNzk4AAAACV9fdXBkYXRlZA==\n	1400770998
session:2afb6b8ad94ef27735b70c1ac491f58400c1ce96                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzNjY5MjYAAAAJX19jcmVhdGVkCgoxMzk4\nMzY2OTI2AAAACV9fdXBkYXRlZA==\n	1400786126
session:c21f1ee4c10436f9d56b05cc25b4d5edb116c41f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTgzOTY3MzAAAAAJX19jcmVhdGVkCgoxMzk4\nMzk2NzMwAAAACV9fdXBkYXRlZA==\n	1400815930
session:36e28b3155e9c7f5f3a41d4da543e1c5ff5027e8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MjU0MTEAAAAJX19jcmVhdGVkCgoxMzk4\nNDI1NDEyAAAACV9fdXBkYXRlZA==\n	1400844611
session:1ce6aa4f84a62713091d560cc9ba0d00b8cfd258                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MjkxNzkAAAAJX19jcmVhdGVkCgoxMzk4\nNDI5MTc5AAAACV9fdXBkYXRlZA==\n	1400848379
session:7052dca3c719f97f92ce25775f0589a6cfbc23d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MjkxNzkAAAAJX19jcmVhdGVkCgoxMzk4\nNDI5MTc5AAAACV9fdXBkYXRlZA==\n	1400848379
session:724a1f6b24808233b1ad00dff4ec8578c223a4e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:953d8a4bde4b44311b9f75d5f36e342b6cf1405c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0Mzg1MTQAAAAJX19jcmVhdGVkCgoxMzk4\nNDM4NTE0AAAACV9fdXBkYXRlZA==\n	1400857715
session:30db36e9ac60b3e296c53592c910e459e4ecb87e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0NTg4ODEAAAAJX19jcmVhdGVkCgoxMzk4\nNDU4ODgxAAAACV9fdXBkYXRlZA==\n	1400878081
session:e3132f824b954881ad98ad4ee219a782c0ca568f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0Nzg2NDMAAAAJX19jcmVhdGVkCgoxMzk4\nNDc4NjQzAAAACV9fdXBkYXRlZA==\n	1400897843
session:c634f524d21b0d833a55826f4804bf9e94a7858a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA0AAAACV9fdXBkYXRlZA==\n	1401017504
session:065314e1a442304aca13d14828c5aec37d1e4b79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:1a69ac05ed3512203e3e82d4894d5b52c14c9ee8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:f6321f94a4a7d0235a1dd8ff7db72c05e546e1fe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:855fd12d9ad067b46acef45d03b3a56e5d8326c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:60351d3911e8b296d9f5c34bd8cec6092d122a53                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:d808da67ed17bbab757f7f6aaa77aaeede9e0f20                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA2AAAACV9fdXBkYXRlZA==\n	1401017506
session:08c7c2ba23d24178459db1a8169bc5f48099de9a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA2AAAACV9fdXBkYXRlZA==\n	1401017506
session:d8f1019e5443f233d4b5304d272646d3ac3ed4cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:2b9b87a30393f20013b22e43141a8adc3e224cd3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:e7b59d5cfd2e8bff1db08d820692143134b4a715                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:657633ea4295ac64d594365568c69a071c504bd8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:cf64e65cd29b6362fde9663c17cbb414c3a61873                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:73ea2fa293c59f07db10e34b7c267189cfcb4817                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:9a3083cd501e6d4aa93c4832dfeabc2d6034150a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:8c86cc3894d3b705570fab6cae217592f4eb85f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:5f8cd79489887a7ff05a63d4eb2c0032bd9c1293                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:e2cc544215916fcea997c69020696df5d1dc4dd5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:45df2479b8de1162f15c2346aa9948a500651051                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:08831f09a5730ffd48d98e483a78d064c1288486                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:8e0b9f04c07ebd4bdcef83cfe9e03f2c4f12c4eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:22a07495d25e75725cb9b03c0d0c0118e3513942                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:46852d940ed0229a338a0b22c6c62d49b4a490b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:17965ebd4dc4b4625202c151b8cb2cc484abeda9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:f9a3a32dc5f017caa5ee2e9e924e70f08d60de85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:aa761d3c39c2af6c749857cbcdef9004da690ef8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:683420f1fad92c7ca917cb0c81315f321a4600c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:bf099969dcb7f84af3848031a721dae6738fabbe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:f648f5a502336865a2c2b566bd2a58d1cb3a472d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:7727abf9d377c7f0a89c390d6f1f71bc737a04a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MDIzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNDAyMzMyAAAACV9fdXBkYXRlZA==\n	1400821532
session:2716763bb60f84275feb5c57f778865c21399fb5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MjU5NjUAAAAJX19jcmVhdGVkCgoxMzk4\nNDI1OTY1AAAACV9fdXBkYXRlZA==\n	1400845165
session:987b800aabd22cc9365d04c619f71d6ed788e06c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MjkxNzkAAAAJX19jcmVhdGVkCgoxMzk4\nNDI5MTc5AAAACV9fdXBkYXRlZA==\n	1400848379
session:3d753aedd89fe009c88fb70dea597f9a1932990d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:fc4a1d03511bbd26202cc021ce320a1ca5b32299                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0NDI0NjgAAAAJX19jcmVhdGVkCgoxMzk4\nNDQyNDY4AAAACV9fdXBkYXRlZA==\n	1400861668
session:cd9ec903280d17392de2e4703bb8497f6120a207                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0NzU3MTgAAAAJX19jcmVhdGVkCgoxMzk4\nNDc1NzE4AAAACV9fdXBkYXRlZA==\n	1400894918
session:124bb686f4736bf5d922f7181d1aff8636d6b980                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1MDIxMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTAyMTA3AAAACV9fdXBkYXRlZA==\n	1400921307
session:8ec60a101a62fd6fc022892d65cb80061b7d1a23                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1ODQ3ODgAAAAJX19jcmVhdGVkCgoxMzk4\nNTg0Nzg4AAAACV9fdXBkYXRlZA==\n	1401003988
session:531875e536af2db90bb27ee3c4eeaf1f6ce28eb7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA0AAAACV9fdXBkYXRlZA==\n	1401017504
session:1cce2c708ee5ef67397dc776ecc028b17e03c918                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:3cb25052ca0b8237de8d79dba5d321505df49490                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:88f99de6742802ee3d1b435ee8ffd0db954d6f34                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:19810315b4c83d503fae5100bb10e272752859fe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:c0ab2a1f995c78cc3a08825b6e3a5c40d4429c8d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA1AAAACV9fdXBkYXRlZA==\n	1401017505
session:3611a178181395cad6afe8b124db1e36a4c20dae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA2AAAACV9fdXBkYXRlZA==\n	1401017506
session:9bba789a5f0140794e6b5e06a60893a98b1d0963                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA2AAAACV9fdXBkYXRlZA==\n	1401017506
session:0d33e6cdb48764d87d482d3f8caa1c1e25115a77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:99f5cb7bab9622fe15bd2297ead78a99287b6ddd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:20b02da0124e22c650869fffbd5c18d9d35acc68                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:3f4e39500be51234579b71e901697a8e95b219d4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA3AAAACV9fdXBkYXRlZA==\n	1401017507
session:f34e09a739ba667a5cff61cb4a3e0f2eebdc1b10                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:c76e777f0d7304aa0fb5948354c9d4b9bfe8cb9a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:8c54052b7b644f3b5522a3a5c09dfcfcc3317783                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:0ed75a0f28355a03975f4c6bd90206bd84acf2ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA4AAAACV9fdXBkYXRlZA==\n	1401017508
session:f488d13b80102b9c36afdf50c6fd5eaad29b1072                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:31a34570c9768ff99e6b8df437be9c90f9bef101                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:52e75ccc039cd5164d00fddafc62ecc63bf5132f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:b0a6fb50087f4fcd0a43deff28b92b54dfaa019e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:1398220b733c4185ee7130dcdc53552c3612da80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:38793458fd9287d56c91eab6b0afc5a76bbda755                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:a426d5c6153deb0379b8088883b12edd106c7cf1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:74be7d02886bf4e9adbd4ff9c8c92024afac61b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMDkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzA5AAAACV9fdXBkYXRlZA==\n	1401017509
session:125e111d30dbbf6d133eb3c717ef2340449dd935                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:df663827b427d7f15de75b4dfba20076e3adedbd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:5a613856fcd2fba14d52e146422b2f3b556f1931                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:73a3561ea7987eebb29d073f1d24b8aeb742743f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:89f6dd8f76736143193b06fa97d03313e26e3b37                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEwAAAACV9fdXBkYXRlZA==\n	1401017510
session:2ca10257e4eef974b26cbf3326e7bba01aea4211                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:16d88e12c30c8da8d6b6f59919abf3bc6e05078e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:f2b93c742b202d5c9b5cc694501475271c3823e6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:5e4b25377149c8c738e782bdd92501336218a380                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:1f71590bbf916762e307efd06c58245aaeef8484                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017511
session:d9c673cd0b5795c13cf5fb0fe6aecb824c56bb32                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:0b0630108b85ec5e85c12d226ec1cb9f03bf17bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:1c5adedf857a3684f76ec5af65a85bb10ef52385                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:3d44b1b01c8de0567835f50b86d8d76829e2ef73                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:5aa42ee607bdc94530cfad281cdb99a577d46c29                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:43563f787e2435e7853e915a4259b42f211c8561                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEzAAAACV9fdXBkYXRlZA==\n	1401017513
session:979fac09635bf8000573475785ad93e2ae4b6d3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE0AAAACV9fdXBkYXRlZA==\n	1401017514
session:35a22b98636fb65afd7959a2cec85e7b0fb0f0b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017514
session:124da1f21ab77b2b8ff352844b15526d3d405bfa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:292dafcd977f2b1385f8500e9dad0a275ef8512e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:89a465bff5b6e6aa36f94b09ae082b317f4bb79d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:1304897fa1b9df6229f3689746d23132eaa421eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:e65cd896a7360d224670d807be04d894a1988196                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:2581805ce1dd0da0bf22b0f8455696fab00fc4e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:bd54b9375ceaccaad982ad1cf5997ad100bab880                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:a160ade22fe67a97778684288403230dea8dfe36                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:138dde202e40cb8f21a6955fbe769c1d24c4690f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:da71a0c0ec6a45e38072cb6266608a6479499726                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:c20df1650d7e56f25c069edbdae31e312c57a2f6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzExAAAACV9fdXBkYXRlZA==\n	1401017511
session:7462ef8530a8862f8870e3ccf4b197a8683cbd4b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017511
session:24bd862d34bb27b8c426a8ff60da0ffa5a62a5c7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:d9b6b1528df774071ba7018be38574b31b331164                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:1b59b832166ca1872ebb85a8b8efaf2dbd3c1ed2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:05c4d038743766a87ab58b182e9509d9a17cbcfc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:61ad7acb32ac8b61760f84456c1fba134219a342                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzEyAAAACV9fdXBkYXRlZA==\n	1401017512
session:fbea8d23d80e2632fb977e8bf4b3f7019eb6a25f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE0AAAACV9fdXBkYXRlZA==\n	1401017514
session:336349739e1e76e5ed3764e4e4be3f7cc4cacbb1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017514
session:df05602ff3a12dcab4dae420bd087a87322ca73f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:f26f5cb7e1345ead22be1a827512705325114766                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:dcba5c788dcb18259f0a2c6b9d88926ce3ce65b1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:6018cba5d29cdfae2b95f10f57c45e15efe292de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE1AAAACV9fdXBkYXRlZA==\n	1401017515
session:f0b8cf2f42de156aa3ce7a792850dd228ba26b39                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:acbea9ce3bf2e592ce3cdf99fc305fb14b5e21b6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:e5ba011fc519ea6f3ee62ab3d73d638f69e05c26                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:97642a774a54ff47f0b9762353e1fdb3b1002fb6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:54f9658c2ec2b793043397a8dc87cc8a04a9bd8e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:79e7276ffe00efecd74d97db02e99d6a4868132c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE2AAAACV9fdXBkYXRlZA==\n	1401017516
session:b60b8be4bd2eab15c52450fcaf97c9f079d230ed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017516
session:a16537b451ee7ce629213fe10092612f2fd86195                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017517
session:35932c92c88085051f874bac02f6162817687280                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017517
session:aca63a791f007b620ef4e571cf65390150b44450                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017516
session:ed0552283940c623587c81cdbdb1e81b3f4ebb2c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017517
session:4c07d988e6473aa6bcf988acfb9097ded621323e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE3AAAACV9fdXBkYXRlZA==\n	1401017517
session:96eb7d5230f7ed970ad29153f161b97bce76b23a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE4AAAACV9fdXBkYXRlZA==\n	1401017517
session:4347f524a5bb5b7c602a644e41e13b0241707418                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE4AAAACV9fdXBkYXRlZA==\n	1401017517
session:ad27f67bd510362b29de85a8f8726ea8f00a8471                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017518
session:828ca7af21fb74a4228f9ad426ce340b1d2a000e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:7765aeae95c2ef622c91e9407f213692682e83e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:6c5413784360e54571897b370735f6ea15f162dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:9b29ca78529202bba8dd1add7ef512ac1c8a7f89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017518
session:81274a61959236811d317202a7553f0942d2efed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:45a0954ef09a8f5553154f53b4a2da359a2c4e28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:19dcb689b822ed488b29b8a6d9a2e6971c051a72                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:ccac89093077e22d07aecf7fa6ed7af162060494                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017519
session:b19aff72fa0cb160afc802201b2bd709d47f2ab7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:964fe4f3137f333d0c1b3f3905c8f3c14b1f0a78                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:560a8a2b3d1c9a626fae2c0b9d5511f5b2375187                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:53eb17714807b5b9bb5b97c3ecea3d8a91992cec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:624288e19aaa1a582e794136eb752035d1aa4d8b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:398291f4ce5f699ac6db547c775e2c89a0018272                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:7a6bc6953fd2cda227fda2d7b4c6042f3ae0e847                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIxAAAACV9fdXBkYXRlZA==\n	1401017520
session:cdc3452e87d416b0c20c3f048d99e88cd2021cbc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:cd4e49dc4f36091ccdeeeec4dff981307c1aec26                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:1bac5a6773c03ac46fd63458bea3bfaebd039e31                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:9fcfb22ffd07bdda4602eafb2d6f71a7df1f0c7a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:f7b10359ecfb7e9a0119d059f5db468faef125ad                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:bbf3852ad8093581a6a091dd7056a81bd72919da                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:f9ac3a48ce6e085882c47aacd20201615e778df5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:290884ffe5f95b8217c736075052f0f0d7e50f9f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:3315c2d550267363c9ef2cdedc6a36dde9655c1e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:bd54905a22c96e98fd0f6f70a21b987105db1bfb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:f4425ace382cf6a6d4882b1daafadb1c4a1b9ccb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017523
session:d4cfc3b182aea73b1dcd6aba8f1a5734daaecd90                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017524
session:8312b755f994c0765602a01e8ac31e6645e82516                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017524
session:25cf0d983b13adb05f981d595a22c52929b1bed7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017525
session:ab573e1bcbac7ffe193d79036abab57225c52978                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017526
session:db2ad04a39dae07523db6ede96acd03af4d5dcf3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:1249632b4e46e83a3fd70c2d1ca7294c40af73c1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:92d46b6a45417be5f8fda283a6ef51cc706ee518                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:4859ad146eab95cde2db0299273760fb527a77e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:c6ff2363ab138d0d6dc16392a54cc199cb5ea46e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:7776cd8e43e1bad78f5e82becdbf77b5dea72bce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:09e359bc57044cee7cb1ec8a778ca11460ca120a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:45979b8cee0100214dc63d827f6224607f309b2d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:5353a218e9407e3f3a48f0cb90027146d8b02efc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:4fe7642ff9d91d27cb18e4927371e1f66abf2639                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:51a5f2c5514dbf62e2e64ae35acaba6acb38f8cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:38340df08e6c710ed808bc3f45ad63b516a9a67f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:e0d4c6807164a8d399272a89923e85b65c7ab114                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzE5AAAACV9fdXBkYXRlZA==\n	1401017519
session:8f723b46ebb3a2edce5e892cdb63fc8f5ae730a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMTkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017519
session:20379a81dda5706af9580f525f86484563d8bd65                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:16427d13de34ec5f6e8b80b897144be802549910                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:ad8abd45777117f9d7e1fd960678a5b29b34bc1b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:047c2f8d13bf0e6d0c14e9df2d28aef8c1b07073                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:acd64a60c5a55381c49027a04170fc5bc3ff923d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:e1bc577e3d11b44a1fcd517ceba725a66514e846                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIwAAAACV9fdXBkYXRlZA==\n	1401017520
session:11772978be8fa36cf3540101b75d49f1b04f7e3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:4eb50f2425f560729bb4f9c2b38dc7befbe5cf4c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:2c92b7f7d5f64621ef2352806e358f6115dd3a7c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:d198dc3969caf81f14b39fd08460c8448ed7ef68                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:e613b673f30843796c2f432425c979ae9484de09                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:f8fbbe896f30dc33027831dcf922b4afd13d186b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIyAAAACV9fdXBkYXRlZA==\n	1401017522
session:ab2695ef5311564bb5a1214f91a687fe13b54201                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:4d7d4b008ec99947df39affc7da01c0e6e02e4c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:c5e2b606197aacb97c9d12f7dc5c1c8efe22ee95                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:84d51d0836f65ba596a047245877c628f385d100                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:0de6f5f7f6b56933cad10932a8ea631604cbe5c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:6ed3ea74e1df01aad364e11b93e7e9b20b145538                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzIzAAAACV9fdXBkYXRlZA==\n	1401017523
session:aaa7a3ae75d5db16839e210b322322b03e759f18                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017523
session:1dcb80fe45b6163459bc5389580d5eeb2fc16be4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017524
session:47dd10676c4343104b6533f9e8e496be7243f4a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017524
session:f8e1af9013bdca4f0e6a25d130c73ac664909495                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI0AAAACV9fdXBkYXRlZA==\n	1401017524
session:baeba885ab692b1c55a22b7190a95eb9d64bb1d8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017525
session:ab6f6dbfafa6b601ba36d9fe1958e1c05815dbde                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017526
session:b4e3c40556845527503826854e8ba2c86a6040ce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017526
session:543b318f4966ccb12d6225264601eb139e729e11                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017526
session:e96bb118937abab6ee01a99d624363a0d0ad053f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017526
session:37a9f2000cd978b3426ae19cf56a7d883d459c60                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI2AAAACV9fdXBkYXRlZA==\n	1401017526
session:c9064386ebd1ca0ddfd309d557143d16c7a60622                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:9d719bfc9efe827c18c7185c9e31a8723f6a7c2c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:e49ded6f007d3a3ed49a32a0e5cc50c77ec13e7a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:25c81f2fe29d30408428fcc136c9e2aeffd004a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:e51313b2a67312a5c5a92105698fa7352a0abe50                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI3AAAACV9fdXBkYXRlZA==\n	1401017527
session:8fbabdc067bf8d5d05ecc4e587b67d28f4042f81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:964c401c98e105b09d44bf6d851049bc49e83f21                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:3dac6884fd4cdd1a9c3b9c46737d6120c184a8c9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI4AAAACV9fdXBkYXRlZA==\n	1401017528
session:5837dcbea5175ac0419cc273d68c4aa13651fecf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:731c6403ccd68e2433981322ef2c357ba24f815d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:59110a05650310183f48407906923071ba137a63                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:114f0ae0eba3cddaa06ff36b2fb5b3d1861e7195                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:89de938fc2aeaa762a5f5f035038bd5d20e0989f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:7cf66c51e82eff8ed55775e0956b2031f4f3ab89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:a0a9e4bc8418a7be20f40a4454a51f8721022ceb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:5e8d94227b3f33bf8c760cf2077ce983fa5c846e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:dba63f53fba78aac887941b5f94d72a1dc90db06                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:b4a1c546728700fd2cff7a67a5408cffefbb33f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:9295c58464c018449e52690556d59243decc3719                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:aae89657c1b26ff15936d8c67f2e861cf276ae48                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:935a65b558e915d72fb738d953cf1685567add34                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMyAAAACV9fdXBkYXRlZA==\n	1401017532
session:31d82f711f6a632b9def0ecce7679eb8f90b955d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMyAAAACV9fdXBkYXRlZA==\n	1401017532
session:74019debaead3d41df9b0477c8baaff9ebe4dd5e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMyAAAACV9fdXBkYXRlZA==\n	1401017532
session:4fa4f69b418e084c029d188a8fa18f1f559b9bce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMyAAAACV9fdXBkYXRlZA==\n	1401017532
session:d4a5d53c48c30004f6c0764ab15079f12ce2b2f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017532
session:03a425c274ed31799fb6f6f403680fc70436c058                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:9b16ba2a0b5b4413c808bcd31b1394b9e6a37902                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:e8d46efb442e60900fee363068344fd1171cfa52                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:1f106c686eef9b1050a1b51611a3f22729fd9ccc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:7884ee693ceca57b4ac0a89eadbc2789fc858177                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:1fde02ceea246e4fe16c5ca762fbccb84a1cddd9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:21817e7503acbeb9a57fecc449ef70177293489c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:f468bab2ec3e6d5d8eb0f25f211dababc9805316                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:048639f78922f4c2e522be012b53f565ad21cb1d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:0fd68f0f8c9cb0612e1e7e6e6684227e05fbd830                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:b9a86c3f9a53717d2d0bcbff908fdaeb8bd9d635                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:2df52c2c686ddc2471551c8239d19cf1b408876d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:7bde25fa5d13e58fe14300e68dc0e494ab16270c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:27aa1802190e0279f62ffad948c9c3532e4c5a30                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:7f430d1c697f2a0fc662cd0b2efb9086a8547b25                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:d0ba46d2cf657b32bf034b4d821aa8c5e1c9ae2b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:d0a41d0a4ccddef01fa37573620575d51d3f66ef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:91327abc004ca6d9a3800b051a2b273f343164d5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:1768e695313899020ad6622573b96ebbe6651495                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:8a7be63f3ab5862361789473a35a1290278b50bd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMjkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzI5AAAACV9fdXBkYXRlZA==\n	1401017529
session:1f7ec80f943a6bb0bbcabaee5642b03400f3ecf1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:4e1f696ba5030d586b79a88c366af962b418aa27                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:5d818daf3197283a0f8863501145fae29308604d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:c31cc78b6a6af39f2564ca7c1fde7f6ee0ce54ae                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMwAAAACV9fdXBkYXRlZA==\n	1401017530
session:3af2887e4f459f4b6662f84909a9a4e95cea1700                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:1b8eebb83cefdd4d6e04ddfdfe73a1c054e78e5d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:779d17faeae16aa98fbdc9b97a9ad37983185c76                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMxAAAACV9fdXBkYXRlZA==\n	1401017531
session:e0f5385e6e2794601dd74fa960623b4c2898b79f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMyAAAACV9fdXBkYXRlZA==\n	1401017532
session:e1252588e91d4c1debcfd8966cbaa4d7c32177b5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017532
session:e2d51a515fa0135d067decdaa73ebe6883e5b04b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:5c6793f784b488bb5de7f9d141f738105f924369                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:bce20ff541b46a2063dd4f81637099cdec8a7262                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:903fa6a27e0aaca878bc1f1394129d9e9ebaa09c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:865159e89798eb09ffc6d660602217ac9405de27                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:e7d128cf2d4a495cbe909b9042928be764d760b0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:7e0495ec41ffa4d902ead773c798412f4cc49eeb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzMAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzMzAAAACV9fdXBkYXRlZA==\n	1401017533
session:ae4218bda5fdd6655145366b495eab673d0c4fd1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:98b19a88b32b4149eecb79ae6837cf0d1c6f4f63                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:256be1db5627535737264f25d8621b6e03220a4b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:a63e4642b36b69ecf8b39cf8ca18d3e066c19def                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzQAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM0AAAACV9fdXBkYXRlZA==\n	1401017534
session:85ede1cffc8460e4e7da182bd0742dc766eff6a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:0a711cc02eef5698f3bb6cb9cd07f66930a409a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:41d86e39040a0c8f76dce9d4e919157217f1fc6b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:bd317c6576a4840b0877f756fca98cc6a7cba4fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzUAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM1AAAACV9fdXBkYXRlZA==\n	1401017535
session:146641d9f0abee414f686e662803baa8b63b681f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:7321f3ee4ec9a9f298523f63583625cbe3e14641                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:abfc80a310e90703b2d1c421a387fc8e17638554                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:5cf625f17e3813b907a947662d86da6c513014fe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:c68ef32b501a2b334b380f56726f0433c2ffc518                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:4a5db013e45b34aaeed493ea6ff9273159d0114b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:ed3e7514cb3978e33dcb9e508586b4bf03e4b042                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:8aed074070ef1d6821c3ea675b90a63019954347                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:b5ea9db8a79386af1c3339cb69ddbbfb5e2e486b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:c74e3dd48ee3f57eb5e289a878f8d7d4ae10e75b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:847b2af74aab8ce995feabf1e6c101062aeda312                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM2AAAACV9fdXBkYXRlZA==\n	1401017536
session:b668cb61bf3c05e89bbde1b6801fe24c1fc9632f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzYAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017536
session:7877bae531b50138af589c197ca248e91e9428de                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:7e018439fbb5aa303e4f9b41f02c57256ead0503                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:cc7043f6cbae27e1feb5b29cd837b716f6dd1bc6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:854857b8ff83c0d7be6292ae85b20b2ea511cdb8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:3eab14248f020804bf34d79d4aee725f1d9c9cb5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:2205eb4c6cd71c71a4b66311e9ef5feb56c5e40d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:2ec20b480710a4e9d2e304f421149c41b19381c5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:716c711d02b3b72856aaa3572f9173099f233efd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:0805968a38ca15cb78c900350fc1cbafaeb18909                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:0e5591f714dbf6f5ae6d22ac7512dd5504ce448d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:c97d7bed7eda73f6b16bf16dc531bb8830650920                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:9f38c940e49f9c5471e63ba172d9afebceffad7a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:0674b7992ac24e3f398b2425223e2c10a27765f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:1c39b502dcef4287a17b83b307999318e4d53f73                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:9effdd3a5c65e37e6fc39f6d81c189ce6d5644dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:f65e9f50b2b0a4d6ede386507ca8948a2e01c956                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:0891ff25e86d1de42ca28c2f5dc8f264d198159c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:fce2ed49b7af6e9309f6ea09895af53232538e53                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:7c36943dd96e5cf5ceb138a2fc66870543daa4f9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017539
session:5d16efcc3c11fa27f4a9896b051c653f13ff9b8d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:4faceb18686e9cd23759c704e8bfe97052afb78c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:eb82c6e9f1dc3917ed8e0a6baf366436a9953419                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:5b4b4ac45e3d46bd89c1d893b971bb4721a58d85                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:d7e3212ebc4ec0abf6346d9e563be93f4e2aa482                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017541
session:090087e10209f90d32ad31294c510c9d2ed2428f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017541
session:6684fc0d635d1f6147ad131a850eaea79ce644dd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017541
session:05c25ed2de9413d7081bb3a7ad3f05ec55cca48f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017541
session:276ae38cc830104d2bf02d813835e7135aaa4787                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:48778f04e2d174be2f3d67ba619aba94497a669d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:cf203316eb46d80bcd80f5ca3f2a15c49e5f754a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:d3e021bf36c87516acbfec12ec440a4caf9c9101                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:212727cc4b3adf1967b153376096f2a0a353049e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzcAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM3AAAACV9fdXBkYXRlZA==\n	1401017537
session:0906739c27034fc440b717b8ad2588080b075d03                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:d05b9f9217100d6d31b8e122045f26de835a7a40                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:0ef4f608d2ffea0683db24233a82c787b2c6c789                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:5005d8ca8003260f464c74bdca4e0e5fa6193e73                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:fa4e6c154ffddd3ad152c7ba1a79d07fb2b4725e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:530d1c008fb6454f8d0ee0b7c4aac4db9257e1b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:d7f2bc081a1b9059e366966d49ad49d131cf3b3b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:9c3e24a67a64feb8387b86015b33ce60588c4c90                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzgAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM4AAAACV9fdXBkYXRlZA==\n	1401017538
session:1405a9ca8deeb2395e788129d35611e7ffd8d604                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:2cf7c7b4a7292bee5582432632a477d597eb2aa8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:eea88d68ad668c030f4b78b80c6214d8490e7264                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:e3d3f005177c6627a95e7f89c7ec1fb44db4853d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:e7257c53876b7518642ec4e8cb7b090bfde84d48                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:338496762c9b9bb68dbf1bfcbb8a342595de81d9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzM5AAAACV9fdXBkYXRlZA==\n	1401017539
session:d03babb1393472c1c252bc1c404ebc77583114fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzMzkAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017539
session:6582a700addfb3ba971f610d73e919f41c1934b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:96ab11cbc7f143d9f35ec2039c3ac94f30da3546                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:ae090446ebea564c4948bda2d4976b03c6eeca1b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:7f7d94e3e00d9f8daff34206838e7fb7795e3328                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQwAAAACV9fdXBkYXRlZA==\n	1401017540
session:65b6f8828d277fcc3224edd49c8d92e27bc2da64                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDAAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017540
session:8c05d0c38399c277fbd5abaef23f6e4e83a74291                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDEAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQxAAAACV9fdXBkYXRlZA==\n	1401017541
session:8c080011c380b810b9b496d628f98634237375ab                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:c6dc1e739519fca409c19cf76177da93d02764cb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:e6a076f126581304fdbac4dfaca4ebd719fa825f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:324a14040fe47bd1b9a75af58c37aead720d6bb9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg1OTgzNDIAAAAJX19jcmVhdGVkCgoxMzk4\nNTk4MzQyAAAACV9fdXBkYXRlZA==\n	1401017542
session:32405a375e9e7571642fac5e6be401e9217f5931                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2MDIzNjAAAAAJX19jcmVhdGVkCgoxMzk4\nNjAyMzYwAAAACV9fdXBkYXRlZA==\n	1401021560
session:d9aa5fd0984693fb901aada6b93a6fa038710de0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2MjU4MTcAAAAJX19jcmVhdGVkCgoxMzk4\nNjI1ODE4AAAACV9fdXBkYXRlZA==\n	1401045017
session:1c2b27bbbdb434b4e2c8f892fa789bf0de990bca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0NzkAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDc5AAAACV9fdXBkYXRlZA==\n	1401059679
session:ece40d61bb9d23dc9c705c097115e600e12fe43b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0NzkAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDc5AAAACV9fdXBkYXRlZA==\n	1401059679
session:49df473f38dfa721b612cd81f9863b65be632e0e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0NzkAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDc5AAAACV9fdXBkYXRlZA==\n	1401059679
session:70a453575d4b5bde27c4573ba339e5204e662850                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0NzkAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDc5AAAACV9fdXBkYXRlZA==\n	1401059679
session:b2a5abc0a1c1f1ad5efdc8e0e9c928e0ede8f65e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0NzkAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDc5AAAACV9fdXBkYXRlZA==\n	1401059679
session:91f48e20e6ff916911e11069c29184ff8ef1a65b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:e401deaee2dd9ab22e796863541b3b9de535fcfa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:3727fa58be89a1aafbdc18ffc925ee06126a4945                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:666de7979f70ff96f991926c2ac25738f9ee3f2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:ab0e1c92f522d7c4e2e785c2bb61c5fa925dce08                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:3cf9b7c693973b3696c37c8d4e84e6aa0d168593                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:7a210c9fe6ef71507502f8d9689c6b1f58ec03af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODEAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgxAAAACV9fdXBkYXRlZA==\n	1401059681
session:5df49f9dc13003b1372d0298c2b385f9a8ffcf18                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDY3MzQAAAAJX19jcmVhdGVkCgoxMzk4\nNjQ2NzM0AAAACV9fdXBkYXRlZA==\n	1401065934
session:55e157638d25c9945f7e1184139ca7f0adddac58                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3MDI0MjAAAAAJX19jcmVhdGVkCgoxMzk4\nNzAyNDIwAAAACV9fdXBkYXRlZA==\n	1401121620
session:b9ba752bce61f634d32f8ee91bcd753249b213f5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:19baddc4475db6e5bb0fe1e5205e56634a4d4837                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODAAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgwAAAACV9fdXBkYXRlZA==\n	1401059680
session:3a1a102c9bf8fa03c453e043fbcece5de2a94273                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODEAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgxAAAACV9fdXBkYXRlZA==\n	1401059681
session:46e785fb6381da3cd83d83259cea21510f02b3b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NDA0ODEAAAAJX19jcmVhdGVkCgoxMzk4\nNjQwNDgxAAAACV9fdXBkYXRlZA==\n	1401059681
session:66eaeffd8f2f118c9db98a0134afff8292e36bd2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg2NjA4NjYAAAAJX19jcmVhdGVkCgoxMzk4\nNjYwODY2AAAACV9fdXBkYXRlZA==\n	1401080066
session:822dc4dbc1784379de25cedf7328b2159ab36949                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4OTM2MzUAAAAJX19jcmVhdGVkCgoxMzk4\nODkzNjM1AAAACV9fdXBkYXRlZA==\n	1401312835
session:2317fc5a2b59f26d0b3218143b5f6e76b44787b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg0MzA2MzQAAAAJX19jcmVhdGVkCgoxMzk4\nNDMwNjM0AAAACV9fdXBkYXRlZA==\n	1401749533
session:8fe29b4f283c9e81f2373344b72d1b23032ef3b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3MDIxNjYAAAAJX19jcmVhdGVkCgoxMzk4\nNzAyMTY2AAAACV9fdXBkYXRlZA==\n	1401121366
session:d240a8999d95abd8d2e49556d5700ac7516a9db6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3MDk3ODUAAAAJX19jcmVhdGVkCgoxMzk4\nNzA5Nzg1AAAACV9fdXBkYXRlZA==\n	1401128985
session:42115a4d648186825877041e9f80da434ba2cb05                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3MjcxMTUAAAAJX19jcmVhdGVkCgoxMzk4\nNzI3MTE1AAAACV9fdXBkYXRlZA==\n	1401749565
session:c88fe31673194f87585db3a7d7842de2fe817a98                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3MjU4MjIAAAAJX19jcmVhdGVkCgoxMzk4\nNzI1ODIyAAAACV9fdXBkYXRlZA==\n	1401145824
session:9984cffc09ff7b0c33ba6b1092bc7763845d6e5d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4MzE0NTQAAAAJX19jcmVhdGVkCgoxMzk4\nODMxNDU0AAAACV9fdXBkYXRlZA==\n	1401250654
session:0c247a7ec2810fd6269c42b0ee903644653550f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NTM4MDMAAAAJX19jcmVhdGVkCgoxMzk4\nODUzODAzAAAACV9fdXBkYXRlZA==\n	1401273003
session:1714d836e80e353645ebd13d6856e8f9c1f8448d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NTg1NjIAAAAJX19jcmVhdGVkCgoxMzk4\nODU4NTYyAAAACV9fdXBkYXRlZA==\n	1401277762
session:8e718bf9b09b88233d361531eebd6ad3abfd3269                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NjY2MTIAAAAJX19jcmVhdGVkCgoxMzk4\nODY2NjEyAAAACV9fdXBkYXRlZA==\n	1401285812
session:0713642a600446d59846b8b90070de8a49d438be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3NDQ4ODQAAAAJX19jcmVhdGVkCgoxMzk4\nNzQ0ODg1AAAACV9fdXBkYXRlZA==\n	1401164084
session:03071459084b149e86d87732948dfa14227e5ccd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3NTQ5OTgAAAAJX19jcmVhdGVkCgoxMzk4\nNzU0OTk5AAAACV9fdXBkYXRlZA==\n	1401174198
session:904ea7e500ae09ea5e9ea89efba112d89a57d3c2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3NjM1MDkAAAAJX19jcmVhdGVkCgoxMzk4\nNzYzNTA5AAAACV9fdXBkYXRlZA==\n	1401182709
session:b5980db04856b68a0da8b06390d7cf675c8dae3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg3ODQwNjYAAAAJX19jcmVhdGVkCgoxMzk4\nNzg0MDY2AAAACV9fdXBkYXRlZA==\n	1401203266
session:a551ee16f769ce03dfcfa2e20025a216af60788a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NzQyNTkAAAAJX19jcmVhdGVkCgoxMzk4\nODc0MjU5AAAACV9fdXBkYXRlZA==\n	1401293459
session:4f79a9e7fda9b3fc7119ff85bfff5225ff0e1073                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5MTAzODQAAAAJX19jcmVhdGVkCgoxMzk4\nOTEwMzg0AAAACV9fdXBkYXRlZA==\n	1401329584
session:176a9a801a8cfec188fb68b4372b2f998e107cc0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NzQ0ODEAAAAJX19jcmVhdGVkCgoxMzk4\nODc0NDgxAAAACV9fdXBkYXRlZA==\n	1401293681
session:24de6ef79df2df6065f494006672c42520399791                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NzcxODgAAAAJX19jcmVhdGVkCgoxMzk4\nODc3MTg4AAAACV9fdXBkYXRlZA==\n	1401296388
session:f44016285da3ad3fcb9c1f0128d46082a1e347b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NzczNzAAAAAJX19jcmVhdGVkCgoxMzk4\nODc3MzcwAAAACV9fdXBkYXRlZA==\n	1401296570
session:f20eca5633fc6060c1e84f156f70437d48cea35b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5MTY0NTcAAAAJX19jcmVhdGVkCgoxMzk4\nOTE2NDU3AAAACV9fdXBkYXRlZA==\n	1401335657
session:d87aa25f5ff04a65089a47aa5d7a4bafc274d13e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5MjA3NjIAAAAJX19jcmVhdGVkCgoxMzk4\nOTIwNzYyAAAACV9fdXBkYXRlZA==\n	1401339962
session:16baa8e6fffe5f0c0f9982922f7b70d0fd326b96                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5MzE4MjAAAAAJX19jcmVhdGVkCgoxMzk4\nOTMxODIwAAAACV9fdXBkYXRlZA==\n	1401351020
session:ecef87c0657dd4c2db39479013a1b1f717cf09dc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5NDQ4MjYAAAAJX19jcmVhdGVkCgoxMzk4\nOTQ0ODI2AAAACV9fdXBkYXRlZA==\n	1401364026
session:a02483f6d3bedefb5d5a1403de5ced1399d750e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg5ODQwMjcAAAAJX19jcmVhdGVkCgoxMzk4\nOTg0MDI3AAAACV9fdXBkYXRlZA==\n	1401403227
session:aa6262dfd53c5de72e93ccc8b7d2931a30b5a6d1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkwMjg1MzAAAAAJX19jcmVhdGVkCgoxMzk5\nMDI4NTMwAAAACV9fdXBkYXRlZA==\n	1401447730
session:07be9109f8ba1a07347268a472c3b63352f892aa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkwMzI1NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMDMyNTcwAAAACV9fdXBkYXRlZA==\n	1401451770
session:e1b0061dad0f669da7dfecebd8b9795009a24cb6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkwMzI1NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMDMyNTcxAAAACV9fdXBkYXRlZA==\n	1401451771
session:4df414490831c80b6e08eba10b823dd07628cdaa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkxNzI0NjIAAAAJX19jcmVhdGVkCgoxMzk5\nMTcyNDYyAAAACV9fdXBkYXRlZA==\n	1401591662
session:ec2acda707902ae4305ddf3ecdf8e124af0c1146                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkxNzYzNTEAAAAJX19jcmVhdGVkCgoxMzk5\nMTc2MzUxAAAACV9fdXBkYXRlZA==\n	1401595551
session:764fc8a0f3813410f0187dd8947d2fc854ca2f25                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkxODc3ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMTg3NzgzAAAACV9fdXBkYXRlZA==\n	1401606983
session:b9b69ef84d7a7f0cfc304ad6cefd1173e62e68f2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkxODk0NDAAAAAJX19jcmVhdGVkCgoxMzk5\nMTg5NDQwAAAACV9fdXBkYXRlZA==\n	1401608640
session:4bb25c9932d55e47b2794b243b684bd750bcf087                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyMDcxMTcAAAAJX19jcmVhdGVkCgoxMzk5\nMjA3MTE3AAAACV9fdXBkYXRlZA==\n	1401626317
session:d276c56f97c0b7d68dcfed0e5dd1a5ffce7985df                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyMjU5OTAAAAAJX19jcmVhdGVkCgoxMzk5\nMjI1OTkwAAAACV9fdXBkYXRlZA==\n	1401645190
session:5d0f51cf3ec8040d1d8b8a9c57cbe352b76f35a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyNTY1ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMjU2NTg4AAAACV9fdXBkYXRlZA==\n	1401675788
session:fe00d65ed68d47dbb6fbb79589ecb734ed5e57e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyODUyMDMAAAAJX19jcmVhdGVkCgoxMzk5\nMjg1MjA0AAAACV9fdXBkYXRlZA==\n	1401704403
session:8bf2fbe9c04c03c3309cdbd764dbbbea3ed41899                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyMTU4MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMjE1ODAwAAAACV9fdXBkYXRlZA==\n	1401635000
session:c099b3af78b05249df8c688f70b49fc4706f2c89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyMjc5MTYAAAAJX19jcmVhdGVkCgoxMzk5\nMjI3OTE3AAAACV9fdXBkYXRlZA==\n	1401647116
session:4dc87e29b52cfe8bc53ddc106a4fa0709447b8b7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyODEwOTIAAAAJX19jcmVhdGVkCgoxMzk5\nMjgxMDkyAAAACV9fdXBkYXRlZA==\n	1401700292
session:3bf42dd3ced67146f281bd8fc6e438b8e947e288                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkyODUyMzYAAAAJX19jcmVhdGVkCgoxMzk5\nMjg1MjM2AAAACV9fdXBkYXRlZA==\n	1401704436
session:ee394e895a694a6bc4354d1b728062b7d3b5b952                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786644
session:5816796f12196802c33e0f0c04b1bb3118a2b650                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786644
session:b942ab7f3e832e1e041eb0460d08ceba38b44aaa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMDgzODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzA4MzgzAAAACV9fdXBkYXRlZA==\n	1401727583
session:4793ac76fd2670f69baa44ba93a2b4994eef7fcf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMDgzODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzA4Mzg0AAAACV9fdXBkYXRlZA==\n	1401727584
session:87e0e77e21bebe930b0202d26e9b7e92b6819644                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMDk0NzcAAAAJX19jcmVhdGVkCgoxMzk5\nMzA5NDc3AAAACV9fdXBkYXRlZA==\n	1401728677
session:07dd2a2a75bcce853358819b7a927eb7b592c766                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMTI1ODEAAAAJX19jcmVhdGVkCgoxMzk5\nMzEyNTgxAAAACV9fdXBkYXRlZA==\n	1401731781
session:bf9a39097cfa1c90095d7f6f47832b09d6bfe0a3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNDM0MzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzQzNDMzAAAACV9fdXBkYXRlZA==\n	1401762648
session:9fcc6c2033a6974256e4bc7669f41e1b9eb18cc9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMTY5NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzE2OTUzAAAACV9fdXBkYXRlZA==\n	1401736153
session:25037029274110a3e6ca3d0afb777696a975394a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMDc5NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzA3OTQ0AAAACV9fdXBkYXRlZA==\n	1402072866
session:0fd036650cd01a1d51c711faaa038a7ec89feb7c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNTI4NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzUyODcxAAAACV9fdXBkYXRlZA==\n	1401772070
session:11718c3dd4a87bea2adeafa23f14a3e41c704809                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMTQ5OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzE0OTk3AAAACV9fdXBkYXRlZA==\n	1401744729
session:70ddb10c3082b8b52d6e82e97a0a43f9be0a101d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMjg5MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzI4OTAxAAAACV9fdXBkYXRlZA==\n	1401748101
session:e9e3bd4572e9fc1c7cb34d5ebf85c4482bc197ca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMjg5MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzI4OTAxAAAACV9fdXBkYXRlZA==\n	1401748101
session:2db60a714db095fa34fc5e3f59d20177d2eb2995                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMjg5MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzI4OTAyAAAACV9fdXBkYXRlZA==\n	1401748102
session:8c731b864bfda48ab264cc14cea5e3735d51aec0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMzMwODAAAAAJX19jcmVhdGVkCgoxMzk5\nMzMzMDgwAAAACV9fdXBkYXRlZA==\n	1401752280
session:b42cb2dfa874948b18b2562e07e32cef54a00780                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNTUyNDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzU1MjQyAAAACV9fdXBkYXRlZA==\n	1401774442
session:ec2e5b33876175325d87210066a83e515bdfbb90                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzMzMwODAAAAAJX19jcmVhdGVkCgoxMzk5\nMzMzMDgwAAAACV9fdXBkYXRlZA==\n	1401752281
session:00cb15c0e33ec756ca4e41e5c4322622b35bf934                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNTkwOTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzU5MDk0AAAACV9fdXBkYXRlZA==\n	1401778294
session:1df10ca490ffe1f2aca7bd7d2ca7b4fe9c3182cd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjA3ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzYwNzg4AAAACV9fdXBkYXRlZA==\n	1401779988
session:fba99dff95f044ce2b908bdd8f4d8623511461e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ0AAAACV9fdXBkYXRlZA==\n	1401786644
session:83f532db8feda7ebc409c3b50e0b774fd32ef8cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ0AAAACV9fdXBkYXRlZA==\n	1401786644
session:ce0d15beb06fd74c7fde88da611dd33f791b8846                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ0AAAACV9fdXBkYXRlZA==\n	1401786644
session:a449b7cdc7f147251b32147703f5461a15ec960e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ0AAAACV9fdXBkYXRlZA==\n	1401786644
session:73ee0128f65a9eb7422db4cac6dcfffee1898abb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:d60e4f85505411e39cae311870b9b945bac6d70d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:208625779043912602c043359ca3450486530db8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:2dcd312105bc3b6e3980d638a8458aa9c9ea3548                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:40ee53cca8f9cbf4f283e4dfe84771c75769b8f1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:f2bf1c1aedb62cb28d11e3e5df421ea1185babf0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:f94a0e4c1a7645115fdcd50591bd1b992b392cbb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:84d2596e6e6c47469303007b86e6d24fb4bf7399                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:2b302c9584f1a0df7c67f9a7687feff6bf24a86d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:38cda9e751501c8bb33f1854778d47b76c60844f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ1AAAACV9fdXBkYXRlZA==\n	1401786645
session:b24c715c3ac36f58653d44312863b87c9019198f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:c45f00cf6ba1b7af35e7d75eeab7e18a572b6ff6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:3372993d0bbfd603f5e12c316762be2d3f1185ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:61578273436fc5ddd76ab7aca3f261a22c311b0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:73bca0475dd53db32ee46a11f7741ffa4ec99fce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:82c5f19b5e637131763169fa1f4dcecb1968d991                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:ee5846886dfd3ea36ce61b51d8a54be75dbd482a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:f8ea2b3f8c1bf7ab8b766613c940e3ab7e1cc53b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:0d3fa62448524ea1a6e2271c3da9a90245fef8df                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:b255c29913e54d55ded2eff8cd58d3fe9114b9e7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:a8ec3aba52ad6e5110cc2dc4cceb74fad3e13f40                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:76769d7a353b4aec7266c72373d8a9ab17dcfe03                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:733c060c52a6bd2d0e62b411fc6abe9437520069                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:43973f5794c31ab20117a34b4e42dcf10191a8c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:b4898106a4dd7479a35da3853a1d0bb08a6010fd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:b1e3571090bf05582b3862dfa17b75852279d7f6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:74695c1bf6799da78f5a1342b8e411570193ca81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:d19b51453c8f0564376759ad6ada58fdb3ad2b30                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:be0df3e4bd22ad6fd8a3c6ae572748f06717c9af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786649
session:5a25ad2850f68a0b3e09e967ec301e68ee5b64e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:1d9da4087d536b7880feb0e9f56639cc2cac941f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:b44255129361c08bad4a9b5b039b861f1d7e0261                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:e0d21f7fa6f3a1447995e8c8895850724daa3226                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:dd2683c46a30b5722c5cccf26be0352de95f8d5f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:1cc48bb164ccabb848ee5790e641fa8bfb436a79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:bb29f4cfb9471d8b83a5bcd7a4d1d7a29f09e7a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:537cdb92ab1731434de58ced20544669aa722fe0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:5aca07249e368ffecdd9a2b0a758aaccbc9bc30a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:da276d4b101a4c0f527e272001fc25e6a2d54405                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:8cd294a41991baf3ca180e1dcba0be9c091c9b1a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:ce7cb37a3fd4d4bfe9da97d00ee0b58e74be9c41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:11a56fa38b8e4a62e8c9a85c810dd8833b6a6df0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:188867039264f9ee577c7af85b508e28fb782101                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:a844db87aba1c1667a868e1a1d9b54249ec662d7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:09c85ec2a5f88a4e9f56e3b4b8c94b3e06d9f573                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:44b073a75395ecd96c6e10b01d0b9eb9d9ecbef3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:739b46557f0ab58e50ed3180a19e6e22f55c11a9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:f6e1dd3a8ab8307a8cef4b799f67d4e70a380fc7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:32011dbe98935fcd945a6a31f13e61c96b4755f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:98332ad2cdc702d8e8ec1ca78af0baec391fd5f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:3de41c42f79426d256c5df43646b03bea9a16d5d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:0011df1fc43e576267fa6d42e165de5f5a2fe319                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:68943350d1be85ebf73c0d1f12fae2c86aa92f97                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:110ba3859b3d286633d69e735eafde67f18a4b35                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ3AAAACV9fdXBkYXRlZA==\n	1401786647
session:47cf58c3edce58ddbe77aacfef9359d4707c3344                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:8775e6d43c6cb7a5ebae59e4e8f6918c2e2d4844                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:536940d4a5549bf21c6bed38e75a11d059f10587                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:3dc0e7992e82a0cd4f2bc1322de7f25bb3b3ba9b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:210be45e9d49995dfd1f02af958b42e5ef490ee2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:ce35ac704f802b914d184521d4b82fd2966c1f1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ4AAAACV9fdXBkYXRlZA==\n	1401786648
session:de77b56da48560259624a9a92d3f730203446910                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:1046b9875309c50d3da82c612925c00baa34cf34                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:89fa073834d17c9930c0f1b24d29b4d484800036                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:2df8ffbe95a05e2c13720c4605a34b2f66cf659e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:7e0ac6696ad8a15ef2f11c81310ea2facabe2400                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:bf88d592459cef9bf6e4039519311d57ff1c1786                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:2628a4aacd226154215eda99f2cafac0ab745324                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NDkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDQ5AAAACV9fdXBkYXRlZA==\n	1401786649
session:4c98662585fa0985ef9865ba574c0b0bf3531918                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:5014b5aa5d95d24c40eea69235f0192c5ed474e1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:5e3052f45bd2a49200605c6bcf671b3c0be611dd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:74ad05fd6242e9cfe2f02ded2d0867c48c7d9c51                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:23926361e6ad1ba6fa8b68230bf3ccb168c588c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:f2935e8d0d4120ebe97cc7f11f7827840f3ab38f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUwAAAACV9fdXBkYXRlZA==\n	1401786650
session:faef745218502303fd85fa9238b7295fdc9aa26a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:5057ad39d8fc3d894c4179bb45371f5ff0920aef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:432fca85a80928b2ecbf5c6855edf41fe2df9020                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:320f4df0247d2f0aa835e2cf96b5e69bd5cff707                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUxAAAACV9fdXBkYXRlZA==\n	1401786651
session:7042d9b1df1a0a54e8f876bee8707daaad081381                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:c63efd5f5f94529a9f83f77c8ec8be24e2d991b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:f8562090848b32f0f4b19bdbf6778847c99a0e2c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:ee220d8563a11ea0c5240560850dc87968037f3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUyAAAACV9fdXBkYXRlZA==\n	1401786652
session:d85171900eddab763aa47b5535eb140db0911d50                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786652
session:498091e42f72c036d1ed124d4f30855bd77099a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:c7b6af8512fed371837dde60c1b070cb486ed87e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:6617ef0508e98d07f15c9295bbaad8a3c09cdf82                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:b2330886061f902f343e725e8af66a49c5af685e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786654
session:dc64688c46ad3d8d3f3a5a8b6b167da9f8b93c35                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:6be785da985de8353c0d2a8cd39a29986a58a197                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:cbf481ba92a187ea4de0cc2dc8f7aa13a514bc8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:c9af9b7feca90c8c513440fb7be94c1e830292d0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:dd8860f6b62a21c146542e70c3a97e8ef6b34fcc                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:f722609065e5b99a6a5975d3e9d2999154d5d411                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:eed7c5acf6e4a0a579960fb33c279fa3b2b487b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU2AAAACV9fdXBkYXRlZA==\n	1401786656
session:e7a94beff71f71370454ac51a0413c32093fbc47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786656
session:b3d6cc47d0562aea69424ec43b0b9393453f3088                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:19cd0cdb2e1d37dfcdcee6df275819ce4252286a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:ae9e7123965e045c844f4847e22ead335fd9e5da                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:e635023d214bcd2c2ff0b9bc0071d43d35a984c8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:309e65aabfeeab0912eca335736cd7dd1f99b984                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:df467f77574fe5fca981bf94d97107baf2adc702                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:f3ad53279997dc783251e69928274720a1bc638c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:452407b423cd1261afd3c30e248bae4e8cebee88                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:e43dd5cc6e5c44af6e467329948cec1fa152667d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:761336b007ac9928f00efca431910fabb28e3e2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:f873d4dd248c1bfca64690decc770fab9b91f643                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU5AAAACV9fdXBkYXRlZA==\n	1401786659
session:bd49287178dbf63b7c4710aed27fdb31b6d67605                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786659
session:a2f27430e8d07f9c7fd56c1bff5735f481dc1596                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:f649107453977c4d25392e32aad248792521a841                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:86527c8baf519560a25eef2258b919d749393da9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:20e8e7d9261fd5c007128a6cca7b555a67bbb250                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:de7b455ad8b0d8f551c72301d7b26f189437ce56                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:8e83627168b2cd25ef083738af3112542f36b625                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYzAAAACV9fdXBkYXRlZA==\n	1401786662
session:7ec741b91cc8d6b6dfaa2481318faae5fc461641                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786663
session:0fd95450b5ad82f94172da6045a18a708e67ede9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:d3840b5b0770323f2ff75a7f670e3cc68e470f77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:de4f7debb2be1655b83f53ee4f55a310dc6edae1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:297cabbea2052c4e1838b0e6b99bbd6396d55cd7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:dc8fb654c25d5cdb88b276051949903343f4cae7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786664
session:b68f5c6d114af53e5d943d550f7a98e669d21024                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:b75cfd5ca8e72da63233a8ed4e1f4c1dfb5ef2bf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:ebaffc69f57af727c4a83430f90b5fc735e71790                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDUzAAAACV9fdXBkYXRlZA==\n	1401786653
session:c2731ce01b614c2a792714fb4cc460ffc81ac5d2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786654
session:eaec8fff0d6a26eb9b08b5d1c92c7f72f0155e9b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:48d934d5ffe51e2449e805503cef8a2324b86454                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:94ed97120f40b900e65076391bdefb2c9fd2a4eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:57d38c8a24be61bedcbaebb2397e139c28840322                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU1AAAACV9fdXBkYXRlZA==\n	1401786655
session:1e4f9f5f93b1b84e0bdc6f8585a8be3fbb518e97                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU2AAAACV9fdXBkYXRlZA==\n	1401786656
session:a69278cdb587dbbf08baef48e885e8077bd22e66                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786656
session:fed26a6b5d8d1944cc9b2e127f53fe1c24d690ff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:0a9b25863fe9e894927df6b2fc77d3ca58772d8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:ec556fc3525b6129f99980137453aa78f414d656                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:eafba9c4928f4369bd56ab84c04f2d2b2d398eac                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU3AAAACV9fdXBkYXRlZA==\n	1401786657
session:d70c65dd8cd0e43f3e566e0e983ae2e1557aac0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:e0161df0e387de51ae8a8be14cc625b9593d7ac6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:047714bcc8c2e00aba016ef745a8e38cbba2e814                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:b1802c1e5826856089cda248e515c6c0d183acad                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:d55b746e7c6950d46691bee575de017641ebc3e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:9fa2267ff737dd5eb2b4649d85d5d6a97747a33c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDU4AAAACV9fdXBkYXRlZA==\n	1401786658
session:c365c0f7ae74824bf300139577ebbf58adb6870e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786659
session:c363fb72f403d4d3882a4dc4d706600d9a8fd77e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:2cfbd2e734eccadfaf7e34e6b94b816e3c33d6d8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:aea6719e1c62ff30443b11e1f4c46e1ef73c53cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:ba2cf8d12da5591b6f80be546e6eb7d9cd75b4e6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYwAAAACV9fdXBkYXRlZA==\n	1401786660
session:9c702c038a2767b7cebf6ba7bd247489bae2ba68                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYzAAAACV9fdXBkYXRlZA==\n	1401786662
session:68957d7345d618e7460f20bf0d88b2eceea5cd4e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYzAAAACV9fdXBkYXRlZA==\n	1401786663
session:852eee64fc012786d16ddac83581fe94ad6dff88                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDYzAAAACV9fdXBkYXRlZA==\n	1401786663
session:8a159010b682b08da5694c870c07cc6a246d1f77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:0514e59bb2796b8a80ba27daeba746da473d1430                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:b3a6e3960d87b0bb4f99c4e187489732974ff8dd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:ef56964ef03728fefc1248e4c65665d8d58fe17d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:da82379970f96b7ada7f4e007e5e4638ec2d75af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY0AAAACV9fdXBkYXRlZA==\n	1401786664
session:ff0fe29f9b3c3e9c840e39352eb3f61f2fd87693                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:43fd8f7c72e02a3047fb13fb5e42d75132ecf3a6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:01c06ce70b33a94d23a9a4f4f70f6acf9926c984                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:6450698352543dc99bc7a0a48e6edb5c80125a4b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:15ba1a6564a14e06db5147b09afc931cbc683ac7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:ec72a7c24d921f2b0f42d5a4382eebfe6c5b64db                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY2AAAACV9fdXBkYXRlZA==\n	1401786666
session:950532ccd3d653a869dc3bdf14da559bb9d29b6f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:345a2f7fd2a0d86e7fab58996b3a5c4ed6dd389d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:81b7c3547208eb666d7f6bd7fe1ddddc5a390284                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:ac0577a73658172139bd3b117780e594f1cc1654                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY1AAAACV9fdXBkYXRlZA==\n	1401786665
session:7ab6d914550c0a10b0079764a103b4f25a87e563                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY2AAAACV9fdXBkYXRlZA==\n	1401786666
session:e7305aeb631e89b5c0dbe76b8b7f38f291f68092                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY2AAAACV9fdXBkYXRlZA==\n	1401786666
session:fc6088a36915ca1dec375409abb017bc1f6f379b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:c91d5d038ec15610834aa81c8463e65ac7daa9a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:d2129beb84bccf39ce9f0cb4d03745cd82fc0162                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:1112272517981a2a33b29d0fd390fe3487578ade                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:f5ab57bc53d3b66429f92f03230336072b5c8e0e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786668
session:9b87570f7e2f0363ffef1409c3062432be23d776                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:47c4b6eed26bafe7ecb39c3c9d128a7513b1e20e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:56b66dd3eab3ce732fc10c44cc42abc03b8b3f40                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:fafa185730d8b54502ee867a15b67e269727bc4a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:95c84c70148e8b3c49f85696426c057b0481494b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:2122f900a042f3bef4280e2b729515d7a1d75994                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:2577c33414c0b2a34334d42a5d3f517292feda3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcwAAAACV9fdXBkYXRlZA==\n	1401786669
session:1947527fd4978d7dfcb76a5735e1a77e22b164a0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786670
session:2967df8f2ec26e074801e7cba1e2976a8fbe4bca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:38febc6f527772141dc974a2f1d0766a16e25ab5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:f1df2435f63da46d18482c73c839c5f2eeade50f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:004d4aebb8ca94d9321da4fe138a0f0893b2980d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:f90fcc81c13c21490739044f9975703f0e2a97da                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:45b111dbf38b848e68cfebdcb36aec4b0279faed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:301c369ca92cc119c206b8c53c4fd03b0955f056                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:d9de8346095463367d9ae55355fe4f9fe1aac5a4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:a0f9870808d67d3fc20409a57cc9190b97b51bf8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:26883a7453532a1a146cfc4b1cc03ee5c204d159                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:335465a95c0066a4b0f4ce3e85144b1d63e6a1f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:c7428ea9c71ae8a5fcd6b6e5f84be57173a0ea47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:9421314658d7275d4804d27660f4cae27a969852                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:dcc5c6d56d9d7b3af35df7f414202652bf5cacd9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:aab2f76d895448a70106659fd962d4f63af26456                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc0AAAACV9fdXBkYXRlZA==\n	1401786674
session:e52a9397e024fbb3fe7ae781f9d4f41efea97aa6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:ee9b6ee34a3c7a971d649a7970ec0fe87e2b3758                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:1193ac95b7cf0f21c3e9488966ff0e256b6dca47                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:36dd955f0c28974bf69fbb12225e4cb7210aff42                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY3AAAACV9fdXBkYXRlZA==\n	1401786667
session:ecbcc4215ab9a93115d48c55b2d5ce583f8872c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:668d59de7abe6c5134767d11af2ee28b476f562c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:771ed5b910d9f0c3679e87c56e9dffc66f4951d5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:3b5ef441350fe9c1895924f21c16c58e747cdd1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:90397517387cd2adb5dbd7eebe884f991a29f0c3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY4AAAACV9fdXBkYXRlZA==\n	1401786668
session:cd2ab81b61a74ee561fb7b30e61ae6e65fc614b0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786668
session:abe4894ca5ac5b530703bbc06fb93db44469cf11                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:5b0c4c6e624ea92b4f5b78c3a893b73e55d077c4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:261c8469e0832ffdfde006b8c5fcb3da1a25bffe                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:e07ee2e4bb3582df2fc178d97fca05e95d4b9b86                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:0d247c3de1de797721c16fa64465ae810b263737                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:c75342d6bd3d76011807854434c341b57373893e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:23596ce286472519e3cce387d95d13ebbc7177a3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NjkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDY5AAAACV9fdXBkYXRlZA==\n	1401786669
session:d20324fd8b42012d497b2d949151d0411a0fadb5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcwAAAACV9fdXBkYXRlZA==\n	1401786670
session:7496c9c484c1edbe3622955ec95e6d4183a692ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcwAAAACV9fdXBkYXRlZA==\n	1401786670
session:a4bad444e6e21d5529877d2a4815f49cf86f2238                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcwAAAACV9fdXBkYXRlZA==\n	1401786670
session:58de559c7e189ea7c6b222e599c7e21f081defba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcwAAAACV9fdXBkYXRlZA==\n	1401786670
session:96381319013a683ef524ae60e4268944003a78f0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786670
session:ba427edf7ae0392df25ec903e9924a1266a26a93                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcxAAAACV9fdXBkYXRlZA==\n	1401786671
session:a906229c34b9bfbb29c2d9665e0b2f86a5a9e747                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786671
session:9e2180961f821d07c0dfe8300ecd03ab37262c4c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:b15ccce548d609f311ae7b8fb63bf5e4e657410c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:dee742b342cef7d1d9e3bb925c11f4410ffde78f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDcyAAAACV9fdXBkYXRlZA==\n	1401786672
session:945081a970d6ef2cc2136e9cc180416cedfbc634                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786672
session:499b12b887d49623ae3097a7810b0b96a89e4b54                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:255a8ffc9e8e85a74270ab81864ca097e888bdf6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:6c3312720641818273f626cf7c95656d217f258c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:d1d348126f2b3943849ddda69f659564ecf72222                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:6baa4cc020effca0a8fc01f5fa5d77330348eb4e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDczAAAACV9fdXBkYXRlZA==\n	1401786673
session:9129992d365d9917d4e64c373d0370dbdefe4604                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:311002ffb979717786cb9628f49a0a03d7328485                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:cfa5cd2e87c19b8f4d2c5c49d842bb203914d649                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:c5029b819fc3ec0600fd74f52d059ad017693087                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:e05e627cefaa9251d3e9131f789f658acc2ee5aa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:113c0a43ce9f26cca684eb42d4fc7ec20a99bce9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:a2e43719f3eea2ca0189d46f3bdbc09637020e9c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:0b80f6c9cfa0389cd377ba92dbe48dde82456060                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:3945b635034da24a43571acb1b18609cfa22817d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:88999c3fb7b84a6c301180ffe8aec9b83db4a13b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc1AAAACV9fdXBkYXRlZA==\n	1401786675
session:dd72e3a37553b1accc924cf8ceac3f4074942a92                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786675
session:eafba188b9d2ab85b2fffaffa14168c4a4d24b4c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:2edf611412e32145ae0295af0a868a18cd1c0c04                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:2e467ee581c51624122654a8c0b39aede82930e0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:f6ae1f82ef638a9b4735f13df7a38eddbd9c32b6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:3d719c1bfb82c959e8d767d728ad321c8bb8d626                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:57e00e993ded3179401195612fcdbf67382b23a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:eb9922b20a508b847a66951d3fb203a00329209a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc3AAAACV9fdXBkYXRlZA==\n	1401786677
session:cf1f7d2fd99f71d2e3207fd17a695ed75a7fd346                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786677
session:7bd5f27054235feb1cf6032c540b47ff077bc8be                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:af491b1e245f14fe99cbee9775e7d0eabc1dd1ba                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:76dbbc42f748e1064c5c95242cf847f7a7144139                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:5cb163522a6b55bb654d581a08ea9a173a3d853a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786678
session:dd3af76d020e62dd9b6becc9a80741bf92a2750c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:52c8ce457e55d8c0405db3e2e11b0f5a3c2ddfd2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:7a314c7a394ae33574c7660037d9dbe9a922c12d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:58e1f392b7f7c37ffbd57c9524aa95adbb562f0b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:40a208621a9640226d035d4d1c8165fe0ba7b96e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:8fd8895efa9751d9875411dd960c9d97e1cace3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgxAAAACV9fdXBkYXRlZA==\n	1401786681
session:3f63d95fd153cf5c1ebf34b1d31e62aec45f63b1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgxAAAACV9fdXBkYXRlZA==\n	1401786681
session:b309fec27eb086896ebffdc7e9ba67e439603e3e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786681
session:f4a248bade9a484100856f676365d2411530da80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:9ef5740fbb1797c222067be68cc19e55fdb702cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:1472f9772c00fb010a1aa17d4ca2b7c583b29d5b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:e4b7771897440dcc6d8ccbb3ceed2bd21b6c7124                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:f2d000cf021354788fbfa2b7f11d07e08605cd81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:aae8f75bd41ca825a39a79c81aac98665355b0a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:d415d2e6df4768bc39f3ddc7412e32688b617d04                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:c9cbb7e4841c6c91c717292c7d0f08272c83507f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:d838c3155234b9295e31646e330f03be6c8f1b7f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:8060d679126257af7575fe62c2d4a48378474f1c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:3547779ce371ccdf39875da96d7b6f63570fe9dd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:291c65829ef9efb442f0dfd9e0eaa4f56246f157                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:5ee1498721b53ad11dae598ffb33eed068e85365                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786683
session:eecea1257a5afbfa681b1301dc6526c3abd4adc7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:bac4c5e8999d6a6e9fab5d8b8bf76d9f1efe8490                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:ae2a7bbcb471be5fdde3a9663bb1cfc36d8c4f2e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:fb6e71d535c99b7a7ad4e8b159ea2e47108125a1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:645b2dc432b0624fcc2955c113cb736900425ac7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:f8bc0e8a9f6375e5237325e27b592489644ffb37                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc2AAAACV9fdXBkYXRlZA==\n	1401786676
session:adc318251ef3e6b028fd49b9249257fc3c0a5a3d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc3AAAACV9fdXBkYXRlZA==\n	1401786676
session:5113d1809c2ac8402443a00e249255738ea87f21                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786677
session:3e71d5c3051ff574d4ab98034b15945a61b205e9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:203d7be940ebb80db96792626c63fcdf3a570f00                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:68485ffa922170cad4708728f87402b5c6b59294                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:99642e34303588fee33492a67f0978bc5fb21c12                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:88742691d8c8867fe60bf162e3883dd372929e5d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:09b38a973cf0aa1ecfb62a61ce391fbba5b8571d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:218f037d77c4b5652f1da0acec5b2045c49d4ae2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc4AAAACV9fdXBkYXRlZA==\n	1401786678
session:35774831d9ec85b972b879b24f2cbb2fbff7dd53                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:fed55029256274bc8c2e004b5d00a300336afda5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:539cd828e3d4e5159d74aaa83f28c5704c5090b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:387d4e34b76fbd079b01cc668044349d68d6f871                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:80cb893c9d712680d792ecfb4b2ba2c6c9beffb0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0NzkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDc5AAAACV9fdXBkYXRlZA==\n	1401786679
session:bb269ef22800d1f53969e59b17e22a432737eab7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgxAAAACV9fdXBkYXRlZA==\n	1401786681
session:744dd8071b8600ad8ddb3d629c23e7febbb902f3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786681
session:44482c073992c6a16e85aa0abcba5a287f3eee07                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:f7e3ce11968ff60fbf5445fe27a9b7f2664e8933                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:d3ad9d08c7af36768fe47407e8fc5331b0bfef96                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:c2eb831179e8585b209682a08e56776860538cb9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:5e7f8ad85373137c957b4b45391ed6068c16de2b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:49059626af8d69b9cbbf1190ab6b1de7972f0e8f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:22870081a1d26fd68d75a4030280a4e62218321f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:e6508d1027499c1b992a179dcb23b55ffd9f4aad                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgyAAAACV9fdXBkYXRlZA==\n	1401786682
session:7aeaf47324d87b2a348546a664c4e9e05ee80b35                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:2af071064a3467a85c8f1d330aca91983801c195                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:967d17a961061cd13b66dae54c4dc8f4683f55c2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDgzAAAACV9fdXBkYXRlZA==\n	1401786683
session:3736665cf9a1ae6d24bd4c31e98ec196a7c51dd0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786683
session:3d16c363de24821809281de9880c61b9235d33b9                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786684
session:92fc3e28dc2a01e4d60779fff3795d5bdd246a4e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786684
session:5db9fe2ef3e2c4d387c81d29b15ec143ec3347f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786684
session:abf71120eec4a0e0253e6d172084f1bd9483edb7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786684
session:f3616da44382eb6648672e189e1059a08fb6ed44                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:5e1852f06021bc82588bbf063f9f000ac20c8642                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:c6c99b91c2485d4e29d68dfe8f55b3a7aada0905                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:9a81c844fcdfa842f148abaf4dcfded7404063a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:a8e7b3e8f70d314e507c4b0f4548741dde710f0a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:6bdd0b617d0017b18e503e269163a693b49cc737                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:5133304699197ddfd0f85c0aff90d64c6169576d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:381e90ac28cb7e941cba22fd9673f0c57cebdaa2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg3AAAACV9fdXBkYXRlZA==\n	1401786687
session:ae381ada6d728ae7969d9f1d087da7fbbb94f028                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786687
session:7d822e70850a3fe2f2ca58ce0c6e6e214a655af7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:839c917638f110187a71240a52ffe9ce696b0326                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:d80ce6e650fb33e2762385ba856e1bc58fbd051d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:3c1a5d93eacddfd1f94501454b5f0f881a7f1d65                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:cffb5ab0f575a40fc6fedc655411bd1111b28f3b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:9968f33b7a41b75d1f07827e3e1f215ab20fef69                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:1115104c6c599dad57a12f0aa2bcbd8131a30611                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:982997771d7262de0b19ca944270189a53d684f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:a5beb17d927dfa9f82643ce4ff01ef570dcba4ec                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:84e4cb8b2813549c96bbcf28a10a282f27226030                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:c23e528fa3283d46ebfb4f8c2f42f8eaafdfda38                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:d9980e73a5d367999ef678c0f2cdd24dbfcf94a2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:b3318b21fb8796940a6d9b7293b76aeecd3290d6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:0664ff4886fa0442ea9021d5d3deac05780c3259                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkwAAAACV9fdXBkYXRlZA==\n	1401786690
session:ba88db1e4a873fc6bab84d5127dfaba8fb79f91f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkyAAAACV9fdXBkYXRlZA==\n	1401786691
session:81d79d932fc30e4c7711dd93366be428c5fcd296                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786692
session:fc8f9b087b564283ebda84c957276d4bedd3919f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg0AAAACV9fdXBkYXRlZA==\n	1401786684
session:e08bdbbc3b10783559fab40bd5b6fd5d3da2035f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:10dfc220f74b256dc031263bd7f9bd26bcbcbc41                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:5a9389c4365458453904fab3dfd0dd3e5b49d9af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:4694ea7bfaa65899ef50018b4fa83cc99ca52152                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:8ebdd733459d7c5391222ed5c96be312de3ed7ef                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg1AAAACV9fdXBkYXRlZA==\n	1401786685
session:c628f103d84343376dbdf193ffbf22cc0fcb5fd7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODUAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786685
session:d534dc0c4d22bc100b6b9cd8db863dd69c106ec8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:9cbe0f210c6c7ab4c8c093ac3069be150e9d750f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:4fa42ad05883c9f51f9d1aa3fe6cfe85c88e1ece                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:b37112e72b57d11d0e3edc2f8e2a29ea3deeff2f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:f393186f3f64f309d3cd962f4d48e33f7386d446                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:8f9f8d9f669cf3cebbc8bd6ebbf064c1aabed338                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg2AAAACV9fdXBkYXRlZA==\n	1401786686
session:8647bf673d1ed73101e0e8eee644cd539b58cc80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg3AAAACV9fdXBkYXRlZA==\n	1401786687
session:f099d2833cc66ea9b16f5e6f972dccf4e644c1cf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg3AAAACV9fdXBkYXRlZA==\n	1401786687
session:a95f6df480b31862fcdf9656b52b3694a863aafa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:776c83bc5ff5deddd5f41ab8a6393abf1d6236d2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:383483dfd4e33b4f8b85d37999c44c776f61edee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:88d2bdb1a1803487ce8651ae8b98b6e8881e1a0a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg4AAAACV9fdXBkYXRlZA==\n	1401786688
session:971ae2fbe8e1a70ee2e467336710b5baf5d3b60e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:83e7693e74b70138a07f50e2cf4cc124650243fa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:7c6e147170e0155b602b0207c1aa86194502ac61                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:cd690eb305e294bb1640129f4e36b05d4c2a2338                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:e5646d975ab4ec1bdb062f2c80012ee45bf5df03                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:9ae68e719188d37fdcb43da2698017d38c7bbf81                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:dcf25cf10fdae48c5b5902c25cc686b345e7627d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0ODkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDg5AAAACV9fdXBkYXRlZA==\n	1401786689
session:f1a5df6fc1ab0411012ef20f9e557189874cd7f4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkwAAAACV9fdXBkYXRlZA==\n	1401786690
session:53b174271def8ea545f104891e2461e0d3789168                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkxAAAACV9fdXBkYXRlZA==\n	1401786691
session:1158a5d38b5be17ebaf85654628eceed3a548134                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkyAAAACV9fdXBkYXRlZA==\n	1401786691
session:145d073fdf57c28398919d18c5055859b4cfaaee                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkyAAAACV9fdXBkYXRlZA==\n	1401786692
session:3a30aef097aa4032e31c2e493bcf002618b1aa89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786692
session:0349def3b10b631ace11b4de7373c973b431d252                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:6f511bcb019caffa28118b1a4751e2239f2f53f7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:d36a4ffc3b3d928bd50e5f23b5e1baeac61887a7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:888eb9531e103c6499710ca2924b135a4084f5b2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:e21ffe87bdd43089d9563cb5b5fe90ff8e0c84c6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:a583d8dbe92b8465f36f7be0f34beb885a1124b5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:b30a5063a541f2b2d3cd942230a00025ac5b13df                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:64117bad629dfa536a917317c008e867ceda1a89                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDkzAAAACV9fdXBkYXRlZA==\n	1401786693
session:d888bb879dc308408b4690e71bb394e584b491b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786693
session:f6a02230c7eb492f7f3b6d560c0ff053f23bc451                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:551d267a207915150be7554e22f1c67079d3ccc6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:a9e2b48a6db3b79fa19743222bf83cbcd7198663                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:8ae0d55255a23dbaafc09cfedc2a3bc0d26d177d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:6ae87759e740559dee33355e68883677a38a952b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:d8b40dea570622a18d39785037bca7a7e4334633                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:a7e796f7e33160009cd6ecac982de4b0d627ad18                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:664dad12b94175ca258dc79090eaa9678005fb6d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:2d79c63b68f56d1ba00e013166b8ae0dbccb207f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:6075fda255226f7b177c70ab38aef8cc98e9ba79                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:1dc63a5fa6134f329fbe9a3cc61560e08e8c03ad                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:e9add0fcf81910ae6442e472cb1a4f40132bfb28                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:11f6881f89ddf3b3d2fefcb463acb1b309ebf062                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:c359ee6cc10d3cbbf4e6f040d3c00b007418a5eb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:8f75db2c3bfd8bbda5704a693e86644c78ce57fa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:b2e2824bc33ba6daee2afd7b6f1ac30d07aa1c95                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:87d3aeaa09f4d70c109f7988e84d2b85acbffea7                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:29eb763078161d2965eb8b9731d3816abd8537d0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:1b0997c41efede7efd5eb0bef7033dfc7971eede                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:209237f58de467034e4074bbe00740115ee42c1f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:3ba0fb3ea4cf4a7fccb94cb2cf429420b3eeb711                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:ac54c7ed4066a553e86aa04a945416859a412521                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:9ef6f7b287280a5ca1570b262bedd05cb8144f5d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786698
session:405735d0e5b185582b51d1e3046e2303bae91104                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:93584aad3d2f3e72555507dd7fc7dfe243a177da                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:a7e5791a57a14b39113dde42c055c970a1407b8c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:2bf5299cf65df45787ede3818ed7cb0b02542bea                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:27fd97f8317e2d90d7630edb037b2dc1442a90ca                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:e6e4bba16fecc74652755f680a45542b1741cb2e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786699
session:bf64a8e0556e74a21146f61012a65c2499041922                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:b8b76e2e0b8eaa739f4f7e8f202217adbea62e9b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:c8f2227616d8a0749b2558de2a936600350cd462                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:d1ef7516144ea1aba1277fe40de93c5c1172d0aa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAxAAAACV9fdXBkYXRlZA==\n	1401786701
session:d020ba718c811832c9b43334a94d3acaf3fd66fb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAxAAAACV9fdXBkYXRlZA==\n	1401786701
session:f92cf6152846558601e254df729999c007773c83                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786693
session:81bb87f3080904b3a9f48854cade56b33359111b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:357f179a42a5979d6bf89bc78fa09a880645794b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:12be7769345b49a1418d9471be5bcf33f38dc381                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:98287d3653328386181539c83e1d72d0e6022a8c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:329896602b7cede015aa8d0075ba7a4b59f8a912                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk0AAAACV9fdXBkYXRlZA==\n	1401786694
session:1bffbce90e14a3e6725a2d76fc7891f46ae16976                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:611b30366c6ada433c5d2bae84e6f78d4b1da006                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:373cebdfd7003df0444efee41a75594260cdc053                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:4015635a1a07d79acc6cca9a047c0c25cd64f096                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:115bdf820c362ab5b441a7e360becfe9aa6d2943                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTYAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk2AAAACV9fdXBkYXRlZA==\n	1401786696
session:0d0fd4c00b4f715c0c0f05a39504743e18a153b4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:6fb0a1867e57f48152e8100a1a5692ef6257667a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:55be1074dedecd65e300e3a280fa7c035bd4dcdd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:d0d7df6c363e3434b0a1176b7057cc08d8c2d093                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:6bf0e3bba7c970c7639a07a474b94d669044055e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:ca983f2485c78ea6eae3342201c7d36a36b29f09                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTcAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk3AAAACV9fdXBkYXRlZA==\n	1401786697
session:97447218abf02e6b6ddf8fb1999713cc10c53aed                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:46171985875e1154303b2b101139264d768025e5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:8dca4d0e029da18ad5107849e13efdb474a84f73                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:56a6fc11e0ad08c4e82a4c34b5e4d26adf58c2e4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:6f2bacccddceb4da6393c84c78d8ea88f2e616af                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTgAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk4AAAACV9fdXBkYXRlZA==\n	1401786698
session:faa99efb786660d338ff6457575af9d463f508b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786698
session:35878bb457220ba6ee4ad09b5be08c0088a76ee6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:b278502fcf9de4a772328322cb19fff42134e798                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:b66e0215579f20490d2e17746466dd670cfbdd87                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:8cbea2e02da1e66f42875f5fdf2ae22cb88eb9ff                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NDk5AAAACV9fdXBkYXRlZA==\n	1401786699
session:97ebee0a209f8ec535e72e50a98211c594ab9314                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786699
session:88c3c93abfa2efa6ea39162f65031ada4ad6b5d5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:f5c614d97c885ac0a429304ebb0ddce34b9bac76                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:a7b03e7567d96206d2d5d447ff9d16a2551e7953                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:6f090378d1284d57e79e1efd0bb2308c556a4758                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:6ad096e4a15648647109dc8e7814cb26e554aca3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:68e8b268f9f8eb30fba7297c85d64651a526a38e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:ad62b123ab5c10dc7574c211340fe862219f8fe4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAwAAAACV9fdXBkYXRlZA==\n	1401786700
session:d25198b6431579e6aa6665b60fa81470035d65d8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAxAAAACV9fdXBkYXRlZA==\n	1401786701
session:b36eb1b20ea504ca8e21044c55ac86ba8bd23d4c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786701
session:9f38651d1f696b863c218539a2d82efa26d8d577                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDEAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786701
session:abd5152a21be4aa71e8e9dfd9f9759f7ab469c01                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:dd689945407353fc3931b999f8217a04e8f09e24                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:635d079b842e0fcf3c10448cb9c169be3a5c1b67                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:90199b3db31268080e16838d2f22a1ef7f26b510                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:9691e996a02445ac3eb17b8402320352d71fb30d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:46fcc5f1a9efaad60471210f241f333a8b5d6b68                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:6076f85897507d7670101ceec840d22dd6212d0d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:9fd9a671ab1ff1815a5cb6b94842cd56ab34105e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:04f6372f8de1dd6a113be60ff496d5c72516d13a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:ae04a6a771cb9d673ef7013ebc404464efb4b69e                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:d0afab2613018e16e422c031c97db33a8ee1e582                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:d9c57847a6185d44b572087f0ef8023643b690ce                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:b7e78445d2d05d44e15c7afd4a473bef2d10ec74                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:13f788051f3352ff4f55339a36b7d1defe6f7f7f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:5b05cb4f08418376045739c874eaccf81645acdf                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMyMTIAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMjEyAAAACV9fdXBkYXRlZA==\n	1401832412
session:1194768b7badf4bc18e1d002b376245f050d155f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNzE4OTQAAAAJX19jcmVhdGVkCgoxMzk5\nMzcxODk0AAAACV9fdXBkYXRlZA==\n	1401791137
session:e375e587c7adacda1c14c5d1add0cc0a94d21fb5                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzODE2MjYAAAAJX19jcmVhdGVkCgoxMzk5\nMzgxNjI2AAAACV9fdXBkYXRlZA==\n	1401800826
session:d130386f6c6bd44272a2d18dade92278579cf16b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxODYAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTg2AAAACV9fdXBkYXRlZA==\n	1401832386
session:3b2c1542b5b4e2b8690bf5d771d95968241a0729                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxODgAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTg4AAAACV9fdXBkYXRlZA==\n	1401832388
session:6754afa1e6ef34f702dd606fb8a55e909a32233b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxOTkAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTk5AAAACV9fdXBkYXRlZA==\n	1401832399
session:7a0e2c327b2bf54e83c231a4f3fa8ecddb1b1b3c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMyMDkAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMjA5AAAACV9fdXBkYXRlZA==\n	1401832409
session:45ad408eb77973900b29e9c613a884c8fcc1fe45                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:be5fc97865fb29aff766e278ff2274c8aed11e6d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:7a60da763395715c05d9f9fb6d6b3a647f8787f8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDIAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAyAAAACV9fdXBkYXRlZA==\n	1401786702
session:ffdc6e47a070093d59093cd27fdc9fd36839b8f0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:c84bbe3f6700ee256246c499eebf33c4b9ae31d1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:f072f4ecbffab7e72e92e9a7eb7231e2a9f2c9c1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDMAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTAzAAAACV9fdXBkYXRlZA==\n	1401786703
session:6b1d9a3dcd298c6d8d148bf790b5eaa8ac23d208                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:10017021f1ac6cd2733c4b17ec1335c3e3b04388                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:a0d69f86d978205812830f4523f79a5995f2ece6                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzNjc1MDQAAAAJX19jcmVhdGVkCgoxMzk5\nMzY3NTA0AAAACV9fdXBkYXRlZA==\n	1401786704
session:4a2e92164735d3cac5b98ffffa7d94aa47cdf58c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTkzOTI3NDAAAAAJX19jcmVhdGVkCgoxMzk5\nMzkyNzQwAAAACV9fdXBkYXRlZA==\n	1401811940
session:0dd294ad9673d0c3fb0fb3ff96fde5975c365244                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxNzkAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTc5AAAACV9fdXBkYXRlZA==\n	1401832379
session:a5f72986fd5b5d4723bb543be9c8fbc8015d9fd1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxODcAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTg3AAAACV9fdXBkYXRlZA==\n	1401832387
session:fd2836d90c97b7764488891625dbd662f42d813f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMxOTMAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMTkzAAAACV9fdXBkYXRlZA==\n	1401832393
session:b5bbad4b0fe14510ab56290b96dfa16b24d3f584                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMyMDAAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMjAwAAAACV9fdXBkYXRlZA==\n	1401832400
session:d63c1ff946cc8295fef81fbab3585e7196b8344c                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMyMTAAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMjExAAAACV9fdXBkYXRlZA==\n	1401832410
session:a6e7be4a469910a41286ea5a37721d138305cd94                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0MTMyMTMAAAAJX19jcmVhdGVkCgoxMzk5\nNDEzMjEzAAAACV9fdXBkYXRlZA==\n	1401832413
session:88689d1bb93a5edee425d62afae8f0f09ac710b8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0NjIzNzAAAAAJX19jcmVhdGVkCgoxMzk5\nNDYyMzcwAAAACV9fdXBkYXRlZA==\n	1401881570
session:d60cfed26fddf957c34611d0f4530a67f3cb4c77                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0NjQwOTYAAAAJX19jcmVhdGVkCgoxMzk5\nNDY0MDk2AAAACV9fdXBkYXRlZA==\n	1401883296
session:36adc5ce37137b0682dd4d1f6f012e9be8cd74a8                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0NjU1MTYAAAAJX19jcmVhdGVkCgoxMzk5\nNDY1NTE2AAAACV9fdXBkYXRlZA==\n	1401884716
session:d4e25b005d97d6ddb60fdf0c4affa03506a9063d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTU2NTAAAAAJX19jcmVhdGVkCgoxMzk5\nNDk1NjUwAAAACV9fdXBkYXRlZA==\n	1401914850
session:b12fb7152fa286cca3e1adf437a77ea1c5068e46                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1MjYyOTQAAAAJX19jcmVhdGVkCgoxMzk5\nNTI2Mjk0AAAACV9fdXBkYXRlZA==\n	1401945494
session:740413b6212067f13cbf1d4fa981dcb383a0a870                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1MzY2NjMAAAAJX19jcmVhdGVkCgoxMzk5\nNTM2NjYzAAAACV9fdXBkYXRlZA==\n	1401955863
session:2a37c90d8c78e8c090c222ae629589dc88aed731                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1NjI5NjYAAAAJX19jcmVhdGVkCgoxMzk5\nNTYyOTY2AAAACV9fdXBkYXRlZA==\n	1405457513
session:259ba59da65f1793cef310b4506b9c18f2b04b8d                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTQ3MTQAAAAJX19jcmVhdGVkCgoxMzk5\nNDk1MjM2AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1401914738
session:805f6143cd0d564de3248efe6e3e93d2f8076dbd                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1NjEzMjMAAAAJX19jcmVhdGVkCgoxMzk5\nNTYxMzIzAAAACV9fdXBkYXRlZA==\n	1401980523
session:90cfca8cd067b00b51398f15a4b680d8533e1170                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTY0NzgAAAAJX19jcmVhdGVkCgoxMzk5\nNDk3MDgzAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1401917790
session:ed9f0f4acfdb2277ff35fd6ac95d72d09c6a472f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTU2OTAAAAAJX19jcmVhdGVkCgoxMzk5\nNDk1NjkwAAAACV9fdXBkYXRlZA==\n	1401916376
session:c377dd2f02c878bdcd197c1a389a8a2318beed00                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTkwNjMAAAAJX19jcmVhdGVkCgoxMzk5\nNDk5MDYzAAAACV9fdXBkYXRlZA==\n	1401918263
session:ebd3416211f719b8b641e046df43230e1ee5670f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1MDI3MzkAAAAJX19jcmVhdGVkCgoxMzk5\nNTAyNzM5AAAACV9fdXBkYXRlZA==\n	1401921939
session:6e60980c7fe59dc7c110774143b5cb9ba189e075                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1NDUzNjEAAAAJX19jcmVhdGVkCgoxMzk5\nNTQ1MzYxAAAACV9fdXBkYXRlZA==\n	1401964561
session:e45e8bac8001d55f5381006f3067a418f65ffb00                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTU3NDAAAAAJX19jcmVhdGVkCgoxMzk5\nNDk1NzQwAAAACV9fdXBkYXRlZA==\n	1402332094
session:76a43d2545dd93d4297667e3bbc9e94b107172b3                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1NjEzMjQAAAAJX19jcmVhdGVkCgoxMzk5\nNTYxMzI0AAAACV9fdXBkYXRlZA==\n	1401980524
session:59d5fc349909786383eb506f883d0e04fef3b005                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk0OTgyODYAAAAJX19jcmVhdGVkCgoxMzk5\nNDk4Mjg2AAAACV9fdXBkYXRlZA==\n	1404419267
session:1ebdd479056af33e4e44c57ffdb04f8d2b5e9eb4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1ODg3ODMAAAAJX19jcmVhdGVkCgoxMzk5\nNTg4NzgzAAAACV9fdXBkYXRlZA==\n	1402007982
session:d8de395d310aa2d3cb8dae2685c7f35ba2389db1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1ODg3ODQAAAAJX19jcmVhdGVkCgoxMzk5\nNTg4Nzg0AAAACV9fdXBkYXRlZA==\n	1402007984
session:757596d1736e8c70ec1cbe83a5e2f84ec6d40900                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1ODg3ODQAAAAJX19jcmVhdGVkCgoxMzk5\nNTg4Nzg0AAAACV9fdXBkYXRlZA==\n	1402007984
session:999a7e2fc82678ad9d8fe34d69ab07612d93671b                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1ODkzMDEAAAAJX19jcmVhdGVkCgoxMzk5\nNTg5MzAxAAAACV9fdXBkYXRlZA==\n	1403717531
session:c24eb2edfef4d080dd46248dbd364317e98e85ac                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk1ODg3ODQAAAAJX19jcmVhdGVkCgoxMzk5\nNTg4Nzg0AAAACV9fdXBkYXRlZA==\n	1402007984
session:a125e8f1f4cd5642741725e6cdadc863e42a36fa                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2MDYzNTkAAAAJX19jcmVhdGVkCgoxMzk5\nNjA2MzU5AAAACV9fdXBkYXRlZA==\n	1402025559
session:db0d2d2bb58014fb83ef8fd800570682dc926614                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2MTg5MzYAAAAJX19jcmVhdGVkCgoxMzk5\nNjE4OTM2AAAACV9fdXBkYXRlZA==\n	1402038136
session:3c324ada2cb6e5233aef6cd478091e6d44c87808                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2MzUzMTUAAAAJX19jcmVhdGVkCgoxMzk5\nNjM1MzE2AAAACV9fdXBkYXRlZA==\n	1402054515
session:2197f6bb4d3de669302d34dacb126b1bae27e744                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDI3MjgAAAAJX19jcmVhdGVkCgoxMzk5\nNjQyNzI4AAAACV9fdXBkYXRlZA==\n	1402061950
session:318cddf0368d4e83d997fcbd5d566641b6efbfc4                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2Mzg1MTEAAAAJX19jcmVhdGVkCgoxMzk5\nNjM4NTExAAAACV9fdXBkYXRlZA==\n	1402057713
session:518ba337f7b4ad2f481e40c1d970fbaa04d9de2a                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTM2NjMAAAAJX19jcmVhdGVkCgoxMzk5\nNjUzNjYzAAAACV9fdXBkYXRlZA==\n	1402072937
session:04cf030a3a1835acb4fa97191d822ca5c8742883                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTI4MDEAAAAJX19jcmVhdGVkCgoxMzk5\nNjUyODAxAAAACV9fdXBkYXRlZA==\n	1402072002
session:f85920b006a81adb80bd81b36a85d58ede4a8bac                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTg4NzU2MzkAAAAJX19jcmVhdGVkCgoxMzk5\nNjYwNDE2AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1402087692
session:59c2eb82d149b59d346d6e85cc559c784cf143d2                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDU4NTcAAAAJX19jcmVhdGVkCgoxMzk5\nNjQ1ODU3AAAACV9fdXBkYXRlZA==\n	1402092707
session:13028eed8c7697406cb4ee0a963c45451e458f80                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTI2ODkAAAAJX19jcmVhdGVkCgoxMzk5\nNjUyNjg5AAAACV9fdXBkYXRlZA==\n	1402072782
session:10f47e87fea12122213559083cbcd6c4dd39c6c1                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTM2NjIAAAAJX19jcmVhdGVkCgoxMzk5\nNjUzNjYyAAAACV9fdXBkYXRlZA==\n	1402072862
session:fcfcb1f2baf89d7cb564a217df5be46b487b813e                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIhgAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDAxNzMzNDkAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwMDE3MzM0\nOQAAAAlfX3VwZGF0ZWQ=\n	1402598981
session:a66c0d449e71498db43df1bb0dd86c014d2a3e0f                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDI5NzcAAAAJX19jcmVhdGVkCgoxMzk5\nNjQyOTc3AAAACV9fdXBkYXRlZA==\n	1402062177
session:b84eba56dd11062ab08f1cf94a70c28c3531edba                        	BQgDAAAABAQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDMzMTAAAAAJX19jcmVhdGVkCgoxMzk5\nNjQzNTgyAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXM=\n	1402062782
session:fc23ce26f5da4252d192f5b1f737d05aaa86478d                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDY0OTkAAAAJX19jcmVhdGVkCgoxMzk5\nNjQ2NDk5AAAACV9fdXBkYXRlZA==\n	1402065699
session:119bf0a84eb5fb6fec84af163afa72315bab3914                        	BQgDAAAABgoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwoK\nMTM5OTY0Mjc3MQAAAAlfX2NyZWF0ZWQEAwAAAAEIigAAAAJpZAAAAAZfX3VzZXIEAwAAAAEKCGxv\nZ2dlZGluAAAADmNyZWF0ZWRfcmVwb3J0AAAAB19fZmxhc2gKCjEzOTk2NDMzMTAAAAAJX191cGRh\ndGVk\n	1402062510
session:187eb3f5f566e2e8c7a7586f62a1c7c466e6dfcb                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDEzMzMAAAAJX19jcmVhdGVkCgoxMzk5\nNjQxMzMzAAAACV9fdXBkYXRlZA==\n	1402061646
session:66c9b5453498e34bb2a23f3820161d03fa7611e9                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAAAAAAACW92ZXJyaWRlcwQD\nAAAAAQiDAAAAAmlkAAAABl9fdXNlcgoKMTM5OTY1OTk0MQAAAAlfX2NyZWF0ZWQKCjE0MDE1NDk3\nMTYAAAAJX191cGRhdGVk\n	1403991739
session:25e46130533dba888b058e067af0adfa7839c718                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDg2NTIAAAAJX19jcmVhdGVkCgoxMzk5\nNjQ4NjUyAAAACV9fdXBkYXRlZA==\n	1402067852
session:cceaf2bef225abb5a13126a89f2c5de965fc4b99                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIgwAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDAwOTk1NzYAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwMDA5OTU4\nOQAAAAlfX3VwZGF0ZWQ=\n	1402522387
session:4134f110d76361510255d7ceadbc26572a86d936                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTM2NzQAAAAJX19jcmVhdGVkCgoxMzk5\nNjUzNjc0AAAACV9fdXBkYXRlZA==\n	1402072874
session:938a5a8e38aa1472cfe66da3ed85c1cf5777cf74                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIkAAAACaWQAAAAGX191\nc2VyCgoxNDAwMjY3NTU0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDAy\nNjc1NTQAAAAJX191cGRhdGVk\n	1402688895
session:941e0526bda2847ff4228f5acaa1ed3c0284a494                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTM2NzYAAAAJX19jcmVhdGVkCgoxMzk5\nNjUzNjc2AAAACV9fdXBkYXRlZA==\n	1402072883
session:999efccffa045a64c9d3625cde9c58aac631f68e                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIgwAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDAyNTAxNjAAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwMDUxNDEw\nMAAAAAlfX3VwZGF0ZWQ=\n	1402933300
session:631282a19c8f5205494873a87bceb58a45d38118                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NTM3MjcAAAAJX19jcmVhdGVkCgoxMzk5\nNjUzNzI3AAAACV9fdXBkYXRlZA==\n	1402072936
session:d2300c5dff63ed53ca2d0cf62acdcec97d13fcf0                        	BQgDAAAAAwQDAAAAAAAAAAlvdmVycmlkZXMKCjEzOTk2NDgxMDAAAAAJX19jcmVhdGVkCgoxMzk5\nNjQ4MTAwAAAACV9fdXBkYXRlZA==\n	1402670193
session:c250135823bea079e24333988fefa471cccc9b23                        	BQgDAAAAAwoKMTQwMDYyMzM0NQAAAAlfX2NyZWF0ZWQKCjE0MDA2MjMzNTYAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403042556
session:009e699379ab6840736162e70ea822192010f163                        	BQgDAAAAAwoKMTQwMDU5OTczNwAAAAlfX2NyZWF0ZWQKCjE0MDA2MjM1MTUAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403042715
session:d52aaa0ab5dac3ec03fc1d25d2ae9fcf8ba3ddf8                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCI0AAAACaWQAAAAGX191\nc2VyCgoxNDAwNzg0MjU1AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDA3\nODQyNTYAAAAJX191cGRhdGVk\n	1403203455
session:07f84b15dc8a62856c1028f5b692f52854ae0e9a                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIwAAAACaWQAAAAGX191\nc2VyCgoxNDAwNjMzNTQwAAAACV9fY3JlYXRlZAoKMTQwMDY5OTM4OQAAAAlfX3VwZGF0ZWQ=\n	1403755951
session:f68b50653eea5876255128ed0498a8cb384ebc48                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCI4AAAACaWQAAAAGX191\nc2VyCgoxNDAwODYwMzU0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDA4\nNjAzNTQAAAAJX191cGRhdGVk\n	1403280900
session:5b9c8d5ed64911258d8f854f70d62c53ce827111                        	BQgDAAAABgoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0KCjE0MDEzOTA5OTcAAAAJX19jcmVhdGVk\nBAMAAAABCIoAAAACaWQAAAAGX191c2VyBAMAAAABCghsb2dnZWRpbgAAAA5jcmVhdGVkX3JlcG9y\ndAAAAAdfX2ZsYXNoCgoxNDAxMzkxMDIwAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGly\nZXM=\n	1403810220
session:413ffe52a74a095cddb5c6277e1c32cdc477b9c7                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtCgoxNDAxMDU5MjQ1AAAACV9fY3Jl\nYXRlZAQDAAAAAQiQAAAAAmlkAAAABl9fdXNlcgQDAAAAAQoIbG9nZ2VkaW4AAAAOY3JlYXRlZF9y\nZXBvcnQAAAAHX19mbGFzaAoKMTQwMTA1OTUwNwAAAAlfX3VwZGF0ZWQ=\n	1403478707
session:641b65ec77eb55bb07cc1249621af74a4b1b7336                        	BQgDAAAAAwoKMTQwMTExNTM0NgAAAAlfX2NyZWF0ZWQKCjE0MDExMjEzMzAAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403540530
session:d791147dbc41de092e8a280f9baac2e3dab76382                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIgAAAACaWQAAAAGX191\nc2VyCgoxNDAxNTQ3NTY0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE1\nNDc1NjQAAAAJX191cGRhdGVk\n	1403966778
session:75c15cd2a7cfa3b1d482897018a24593789d1baa                        	BQgDAAAABgoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0KCjE0MDEzOTEyNzYAAAAJX19jcmVhdGVk\nBAMAAAABCIoAAAACaWQAAAAGX191c2VyBAMAAAABCghsb2dnZWRpbgAAAA5jcmVhdGVkX3JlcG9y\ndAAAAAdfX2ZsYXNoCgoxNDAxMzk3MzQzAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGly\nZXM=\n	1403816543
session:9b32726f9f9c66b31ed40147a2ace5617f40b83f                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJIAAAACaWQAAAAGX191\nc2VyCgoxNDAxNDEyMzMxAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE0\nMTIzMzEAAAAJX191cGRhdGVk\n	1403831531
session:b34d027811665415c0252da46448fa25583a516e                        	BQgDAAAAAwoKMTQwMTE2MjU0MwAAAAlfX2NyZWF0ZWQKCjE0MDExNjI2MDcAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403581814
session:38bcb052986c45b20cbdee965e9022d5cf21dd42                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJQAAAACaWQAAAAGX191\nc2VyCgoxNDAxNzQ4MjQzAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE3\nNDgyNDMAAAAJX191cGRhdGVk\n	1404167443
session:354fc31a9b42c011b979f3af59fe4b3fa9cdff70                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCI8AAAACaWQAAAAGX191\nc2VyCgoxNDAwODYwNjg0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDA4\nNjA2ODQAAAAJX191cGRhdGVk\n	1403281725
session:a5ff9894ea6a4d8e9895aa0fabbd2c193b04bcae                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJEAAAACaWQAAAAGX191\nc2VyCgoxNDAxMTE1MDkyAAAACV9fY3JlYXRlZAoKMTQwMTExNTA5MgAAAAlfX3VwZGF0ZWQ=\n	1403534292
session:a7af066becf6ef2347da658dc2702ac7d81fb16c                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJoAAAACaWQAAAAGX191\nc2VyCgoxNDAxODIzMjQwAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE4\nMjMyNDAAAAAJX191cGRhdGVk\n	1404242451
session:4bc7cf68f9b9e45de5f1c3d87036740d6646df48                        	BQgDAAAAAwoKMTQwMTIwODM4OQAAAAlfX2NyZWF0ZWQKCjE0MDEyMDg0MzEAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403696601
session:60e411c642f734ec4436599ac18eeac69fe78875                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJEAAAACaWQAAAAGX191\nc2VyCgoxNDAxMTE1MDkyAAAACV9fY3JlYXRlZAoKMTQwMTExNjQxMQAAAAlfX3VwZGF0ZWQ=\n	1403535611
session:3cf003dd96885b8c814739e0a2ba6f08645625bb                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ0AAAACaWQAAAAGX191\nc2VyCgoxNDAzMTg4MzI2AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDMx\nODgzMjYAAAAJX191cGRhdGVk\n	1405607545
session:76f7c509e03a8310c906c6eb5e1f2d6f3a11bd1f                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIgwAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDEzMTE3NDUAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwMTMxMTc0\nNQAAAAlfX3VwZGF0ZWQ=\n	1403731852
session:e5609f9d8edfb1336d236dd79c038bebc6d63943                        	BQgDAAAAAwoKMTQwMTY1Njk4NAAAAAlfX2NyZWF0ZWQKCjE0MDE2NTcyMDEAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1404076541
session:3d9eff1a1dcb8ee96c76c1d99f8de46a57d91b21                        	BQgDAAAAAwoKMTQwMTMyODg0MQAAAAlfX2NyZWF0ZWQKCjE0MDEzMjkzMDkAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1403748509
session:00e8159697ae22c291aca4bda674757a8c3827f7                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJsAAAACaWQAAAAGX191\nc2VyCgoxNDAyMzI0NTU4AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDIz\nMjQ4NTAAAAAJX191cGRhdGVk\n	1404744050
session:5d1ad580b079a5e95f400cecfbbbcfeefd36d775                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJQAAAACaWQAAAAGX191\nc2VyCgoxNDAxNDgzNzYxAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE0\nODM3NjEAAAAJX191cGRhdGVk\n	1403903091
session:c7e09e9627a5702dfc61e02d63a212e35d0f54f3                        	BQgDAAAABgoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0KCjE0MDE4OTcxMzcAAAAJX19jcmVhdGVk\nBAMAAAABCIMAAAACaWQAAAAGX191c2VyBAMAAAABCghsb2dnZWRpbgAAAA5jcmVhdGVkX3JlcG9y\ndAAAAAdfX2ZsYXNoCgoxNDAxODk3MTU2AAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGly\nZXM=\n	1404316356
session:53f486aa1c1cc7c869f7afde73d1716db2ffdb73                        	BQgDAAAAAwoKMTQwMjg5MzQ3MwAAAAlfX2NyZWF0ZWQKCjE0MDI4OTM2NDAAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1405312840
session:1fee3dcc146665a9f6e1f42d458f79f71b1268d9                        	BQgDAAAABAoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIkAAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDEwNTk2MTIAAAAJX19jcmVhdGVkCgoxNDAxMDU5NjEyAAAACV9fdXBkYXRlZA==\n	1404536974
session:973b52673384d545558df7dcf8128a28fd7a3017                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJcAAAACaWQAAAAGX191\nc2VyCgoxNDAxNzQwNTUyAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDE3\nNDA1NTIAAAAJX191cGRhdGVk\n	1404159808
session:91312d68765c6e8ddc4776ab9d61de1645361cf2                        	BQgDAAAABgoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0KCjE0MDI0NDAzNDQAAAAJX19jcmVhdGVk\nBAMAAAABCIoAAAACaWQAAAAGX191c2VyBAMAAAABCghsb2dnZWRpbgAAAA5jcmVhdGVkX3JlcG9y\ndAAAAAdfX2ZsYXNoCgoxNDAyNDQwMzYwAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGly\nZXM=\n	1404859560
session:c4d47eec1a6c7db7fbde6dce3cab449bee78a12e                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ0AAAACaWQAAAAGX191\nc2VyCgoxNDAzMTkxNDQyAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDMx\nOTE0NDIAAAAJX191cGRhdGVk\n	1405610647
session:c0f515496ab6a06aae5f0e0910045cde80423d7e                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJAAAAACaWQAAAAGX191\nc2VyCgoxNDAzNDkwMjM4AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM0\nOTAyMzgAAAAJX191cGRhdGVk\n	1405909437
session:079f160fb4624ae538cb50f785b0c8d0ba2c4f3f                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJEAAAACaWQAAAAGX191\nc2VyCgoxNDAzNTQ3MDg2AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM1\nNDcwODYAAAAJX191cGRhdGVk\n	1405966286
session:4796909c841372839ea1ff12ecbc97de7f210ae2                        	BQgDAAAAAwoKMTQwNDA4NDcyNAAAAAlfX2NyZWF0ZWQKCjE0MDQwODQ5MTYAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1406504116
session:31585f1aa674384ba8cd3e93a74ad6ae6345499c                        	BQgDAAAAAwoKMTQwMzU0NzA4NwAAAAlfX2NyZWF0ZWQKCjE0MDM1NDc0MTkAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1405966619
session:36563818bfa0aa0e1b89adb00eedaace03fc21e9                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJIAAAACaWQAAAAGX191\nc2VyCgoxNDAzNTczNzM0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM1\nNzM3MzQAAAAJX191cGRhdGVk\n	1405992935
session:119faae0c3cf1a9bbfa5bb1ed2bab82f84f6f606                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJIAAAACaWQAAAAGX191\nc2VyCgoxNDAzNjYzNzYzAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM2\nNjM3NjMAAAAJX191cGRhdGVk\n	1406083059
session:25a8c62f9fbd52d489469653749152ba102fafcd                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJEAAAACaWQAAAAGX191\nc2VyCgoxNDAzNzE2MzYxAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM3\nMTYzNjEAAAAJX191cGRhdGVk\n	1406135561
session:977942979c90da4c8349b9edf91a166f2b90370c                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJwAAAACaWQAAAAGX191\nc2VyCgoxNDIxMzY1MzExAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MjEz\nNjUzMTEAAAAJX191cGRhdGVk\n	1423784620
session:c55b0ac454573da6d275babd5ee1793d850c437b                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJwAAAACaWQAAAAGX191\nc2VyCgoxNDA3NzYyNzc4AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDc3\nNjI3NzgAAAAJX191cGRhdGVk\n	1410182149
session:e7061193c954e35ae02b1fc5cebce591ea1f2997                        	BQgDAAAAAwoKMTQwMzcxNjM2MQAAAAlfX2NyZWF0ZWQKCjE0MDM3MTY4NjQAAAAJX191cGRhdGVk\nCIAAAAAQX19jb29raWVfZXhwaXJlcw==\n	1406136064
session:710e4dcf98bf5fafc0cfb2be9df5d6dc9d9176fe                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJQAAAACaWQAAAAGX191\nc2VyCgoxNDAzNzU1NTI5AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM3\nNTU1MjkAAAAJX191cGRhdGVk\n	1406174729
session:3a630cf2284385d2955b1c37641c6435c3496951                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJsAAAACaWQAAAAGX191\nc2VyCgoxNDA0NzQ5ODc0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDQ3\nNDk4NzQAAAAJX191cGRhdGVk\n	1407171568
session:709b3b10209a53bcdf16b8360c40d582686db52b                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ8AAAACaWQAAAAGX191\nc2VyCgoxNDA0MjY4OTkwAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDQy\nNjg5OTAAAAAJX191cGRhdGVk\n	1406688230
session:65ed507a6f57fe82769ca8bda752db7bbde0ed38                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ8AAAACaWQAAAAGX191\nc2VyCgoxNDA0MjgxODk5AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDQy\nODE4OTkAAAAJX191cGRhdGVk\n	1406701157
session:66fbbe772aa001fbcbc54090687db1b0a76f3fd8                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKIAAAACaWQAAAAGX191\nc2VyCgoxNDEzMDU0MzY2AAAACV9fY3JlYXRlZAoKMTQxMzA1NDM2NgAAAAlfX3VwZGF0ZWQ=\n	1415474410
session:e8e823f961479019e5bf78a1d7ac46b22bc0a8a6                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJsAAAACaWQAAAAGX191\nc2VyCgoxNDAzNzkyNDI4AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM3\nOTI0MjgAAAAJX191cGRhdGVk\n	1406213158
session:9e82d5b3af491da01ced29981043763ed8a4d3bb                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIngAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDM4MTEyNDEAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwMzgxMTI0\nMQAAAAlfX3VwZGF0ZWQ=\n	1406230826
session:32bed47495dc51cfba15c0cf0e297260ac098e6f                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ4AAAACaWQAAAAGX191\nc2VyCgoxNDAzODExMTAzAAAACV9fY3JlYXRlZAoKMTQwMzgxMTEwMwAAAAlfX3VwZGF0ZWQ=\n	1406230304
session:f3d0ac94562190321e060278d547c2676fa5a4d8                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKEAAAACaWQAAAAGX191\nc2VyCgoxNDA0NzYwNTEwAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDQ3\nNjA1MTAAAAAJX191cGRhdGVk\n	1407179732
session:dafe5bd7496ec41d07859ee462ea604ef0001224                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIgAAAACaWQAAAAGX191\nc2VyCgoxNDAzOTgxMDkwAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDM5\nODEwOTAAAAAJX191cGRhdGVk\n	1406400290
session:f8a83ea3f6ec9ae09928ac77de5d2eb0b62c29a6                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJwAAAACaWQAAAAGX191\nc2VyCgoxNDA1MzE5NTEwAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDUz\nMTk1MTAAAAAJX191cGRhdGVk\n	1407738774
session:9d5a0b7e9928efb94b0a1938294c87f5db108363                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKAAAAACaWQAAAAGX191\nc2VyCgoxNDA0NDE2ODA5AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDQ0\nMTY4MDkAAAAJX191cGRhdGVk\n	1406836164
session:0921a912e8eea04c3911335beff7a47fff0761ab                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIhgAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDg2NDE0NTQAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwODY0MTQ1\nNAAAAAlfX3VwZGF0ZWQ=\n	1411060663
session:e2a1d092407276c6108aa1c6d5d050c561c6cd64                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCJ8AAAACaWQAAAAGX191\nc2VyCgoxNDA2NTY2NDU2AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MDY1\nNjY0NTYAAAAJX191cGRhdGVk\n	1408985656
session:f2df2c4c3ab3fc55eb10577392c65b61fa7cf936                        	BQgDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAEIhgAAAAJpZAAAAAZfX3VzZXIK\nCjE0MDg2NDMxMDUAAAAJX19jcmVhdGVkCIAAAAAQX19jb29raWVfZXhwaXJlcwoKMTQwODY0MzEw\nNQAAAAlfX3VwZGF0ZWQ=\n	1411062719
session:bb35b97851ece88fb765adad341363ccddb43daf                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKQAAAACaWQAAAAGX191\nc2VyCgoxNDIxMzM1NDM5AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MjEz\nMzU0MzkAAAAJX191cGRhdGVk\n	1424114562
session:388d4c2d7f5f44482125eb26ba712bd2c58eb834                        	BQgDAAAABAoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKMAAAACaWQAAAAGX191\nc2VyCgoxNDE0MTc0NTY2AAAACV9fY3JlYXRlZAoKMTQxNDE3NDU2NgAAAAlfX3VwZGF0ZWQ=\n	1416593798
session:6d7641aff4d835b192ede997f8c0a5479e7f818d                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIgAAAACaWQAAAAGX191\nc2VyCgoxNDMzMzQ2NzM4AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MzMz\nNDY3MzgAAAAJX191cGRhdGVk\n	1435765938
session:97955ee7fc4a83969a932381af65b6816b48c4cc                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCKcAAAACaWQAAAAGX191\nc2VyCgoxNDMzMzQ2MDM3AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MzMz\nNDYwMzcAAAAJX191cGRhdGVk\n	1435765262
session:9402981f2e150ec350723ac013d9558da658e789                        	BQgDAAAAAgoKMTQzMzM0NTY3OQAAAAlfX2NyZWF0ZWQKCjE0MzM4MDM5NzYAAAAJX191cGRhdGVk\n	1437055631
session:99650f67ac8b221f8e00860eb001c518fb17b5f7                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIkAAAACaWQAAAAGX191\nc2VyCgoxNDMzODAwNDMzAAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MzM4\nMDA0MzMAAAAJX191cGRhdGVk\n	1436219712
session:503021691b43b6acda8e0a1eab4176f6e584c3bc                        	BQgDAAAABgoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0KCjE0MzMzNjc5NDIAAAAJX19jcmVhdGVk\nBAMAAAABCIYAAAACaWQAAAAGX191c2VyBAMAAAABCghsb2dnZWRpbgAAAA5jcmVhdGVkX3JlcG9y\ndAAAAAdfX2ZsYXNoCgoxNDMzMzY3OTYyAAAACV9fdXBkYXRlZAiAAAAAEF9fY29va2llX2V4cGly\nZXM=\n	1435787162
session:b2f93a618d2059d99ebd7ac888402351c2274006                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIkAAAACaWQAAAAGX191\nc2VyCgoxNDMzODU1MzA0AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MzM4\nNTUzMDQAAAAJX191cGRhdGVk\n	1436274504
session:93b48b7acec1286b230ed4fdab642ed91f786fef                        	BQgDAAAABQoLbm9fcGFzc3dvcmQAAAAMX191c2VyX3JlYWxtBAMAAAABCIkAAAACaWQAAAAGX191\nc2VyCgoxNDMzOTg5NzE5AAAACV9fY3JlYXRlZAiAAAAAEF9fY29va2llX2V4cGlyZXMKCjE0MzM5\nODk3MTkAAAAJX191cGRhdGVk\n	1436408919
\.


--
-- Data for Name: textmystreet; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY textmystreet (name, email, postcode, mobile) FROM stdin;
\.


--
-- Data for Name: token; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY token (scope, token, data, created) FROM stdin;
problem	A5jsTQGRfkHdCAZiGW	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49313a312c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 19:09:13.960319
email_sign_in	FmxgrFCSMisoAKAor7	\\x41313a342c54353a656d61696c2c5432303a6d616764616d6f72656c40676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c	2014-03-06 19:11:09.050658
problem	AsbhtCAAvxDhB5vL2Y	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49313a332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 19:45:32.610299
email_sign_in	GEgFSLFC2T6PCNVeNX	\\x41313a342c54353a656d61696c2c5432303a6d616764616d6f72656c40676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c	2014-03-06 19:48:03.422312
comment	EPgyccDDJjH7DEXNkX	\\x41313a342c54383a70617373776f72642c4e54343a6e616d652c5431313a4572696b61204c757175652c54393a6164645f616c6572742c49313a312c54323a69642c49313a312c	2014-03-06 19:50:00.215121
problem	ARJBPeG79QxcFjhXzj	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49313a342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 20:20:16.49086
email_sign_in	AuLyGyC4c5hgFRojc2	\\x41313a342c54353a656d61696c2c5432303a6d616764616d6f72656c40676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c	2014-03-06 20:22:06.555257
problem	AAigQPDEiEpXAcHvPm	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49313a352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 20:40:49.007647
problem	AU4FRXHD8AkAC55kBb	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49313a362c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 20:43:24.073445
comment	FNywg9DwC23uBdCRZU	\\x41313a342c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54393a6164645f616c6572742c49313a312c54323a69642c49313a322c	2014-03-06 20:43:59.655965
email_sign_in	Evjf9oFRGfmQF73J4y	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-03-06 20:44:15.001756
email_sign_in	DLsCvMEUjmupEfcaJR	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-03-06 20:47:27.469838
problem	CQbMg8AQaJWdGgMQQ5	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49313a372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-06 20:49:34.718565
email_sign_in	CTngnrFxcZnrGBePHM	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-03-06 20:51:37.124474
email_sign_in	EQ5kKaGfyiVZC4PmdE	\\x41313a342c54353a656d61696c2c5432303a6d616764616d6f72656c40676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431363a4d616764616c656e61204d6f72656c202c	2014-03-06 21:08:39.68908
email_sign_in	DsWAqbEeZKcKEdEVfp	\\x41313a342c54353a656d61696c2c5432303a6d616764616d6f72656c40676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c	2014-03-07 12:11:17.988278
comment	ACqrvAExFE7sDnYksc	\\x41313a342c54383a70617373776f72642c4e54343a6e616d652c5431313a5061756c61204d6f72656c2c54393a6164645f616c6572742c49313a312c54323a69642c49313a332c	2014-03-07 13:08:22.301028
problem	G67TdFB9tE4VDqDmkp	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49313a392c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-07 13:28:56.350437
alert	CxyngKDDf5aJETvM7Q	\\x41313a332c54353a656d61696c2c5431363a6d61676461406d61636c6574612e636c2c54343a747970652c54393a7375627363726962652c54323a69642c49313a332c	2014-03-07 13:40:42.14103
problem	E8BH3gGH6fCABZzuft	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431353a526f647269676f207175696a6164612c54323a69642c49323a31302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-07 14:48:43.503086
email_sign_in	BUKphNDRi48vFk22a7	\\x41313a342c54353a656d61696c2c5432373a6c75697366656c697065616c766172657a40676d61696c2e636f6d2c54383a70617373776f72642c5436303a24326124303824534e4c6345476a445a4866524b48774576653079764f78393070762e4d507962355a7033322e3558304175347358627163444656572c54313a722c54323a6d792c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c	2014-03-07 18:54:41.153533
problem	CLJ4D2Aqj33gBBJ2XT	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49323a31342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-25 14:48:40.861601
email_sign_in	ESsMiNBhUjihDZFpym	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-03-25 14:49:43.841311
problem	DabwzaGysoX7Ci2jNa	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49323a31362c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-03-25 18:10:36.411089
questionnaire	DkpNZXDAVTbDGjFNUg	\\x49313a322c	2014-04-03 20:00:21.809863
questionnaire	CTAAGXAmsNnADC29NG	\\x49313a332c	2014-04-04 16:00:22.248317
questionnaire	GVm5QMEPntXQAaM38a	\\x49313a342c	2014-04-07 19:00:20.470151
problem	GA8QHeCq6PgSAPFa6n	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a31372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-15 18:05:29.093601
problem	EZC2H6CeftqUEQzdUB	\\x41313a352c54383a70617373776f72642c5436303a24326124303824526a43584a4661416e735963506c663470745945714f6857627370584f50567574306c385835416249333332436e38647842687a4b2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a31382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-15 18:13:23.823389
problem	GjSPG9DE3DkCEvyfPq	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a32302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-15 18:42:46.276687
problem	DWsR3mDF4xyvGbib8f	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a32312c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-15 19:01:56.725943
alert	FiNJDkEvB5T7CC6jmV	\\x41313a332c54353a656d61696c2c5432373a6c75697366656c697065616c766172657a40676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49313a342c	2014-04-15 19:02:08.090197
email_sign_in	EWGMHMAokd6BEQBoKj	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c	2014-04-17 19:58:36.912275
problem	F2CuvAFq3r5TBURrab	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5432303a4d616764616c656e61204d6f72656c205275697a2c54323a69642c49323a32322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-19 22:16:30.839467
problem	AfE6KVA9QbPVExBnm8	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5432303a4d616764616c656e61204d6f72656c205275697a2c54323a69642c49323a32332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-19 22:29:45.549013
problem	CAZkk8DpAHjaEYiCPd	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431343a4a6f72676520686569746d616e6e2c54323a69642c49323a32342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-19 22:44:39.038517
email_sign_in	GNZynUD8n2MhEUGtnh	\\x41313a322c54353a656d61696c2c5432343a6d616764616d6f72656c40636975646164766976612e636c2c54313a722c54393a7265706f72742f32302c	2014-04-19 23:02:07.199584
alert	DwQUYCGK5gG8FTt84b	\\x41313a332c54353a656d61696c2c5432343a6d616764616d6f72656c40636975646164766976612e636c2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a31352c	2014-04-19 23:02:07.391268
problem	DAYW6hBmzRp8AiKrcw	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a32352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-21 13:07:39.264475
questionnaire	DDZ2VRCWFCEZBq3g8w	\\x49313a372c	2014-04-21 20:00:21.405363
questionnaire	Cxd5qrEbV2cEHCiqHc	\\x49313a382c	2014-04-22 15:00:20.899015
questionnaire	AJHm9NCRxpMzCNPADv	\\x49313a392c	2014-04-22 15:30:28.677064
questionnaire	FxzhtxFPB5AgDHesat	\\x49323a31302c	2014-04-22 18:30:28.728982
email_sign_in	Ed57LnCUxV22CQob8T	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c5436303a243261243038244f3170586c6675706e43335a536f4c61477852526b2e49633837726873306e74434342626554705a6b3157633165413674547456472c54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-04-24 17:49:09.343455
problem	GwjQ8UCeE23YBLtgEe	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a32362c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-24 19:44:40.619948
comment	HHDobFF9jWpHAsVk7w	\\x41313a342c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54393a6164645f616c6572742c49313a312c54323a69642c49323a31342c	2014-04-24 19:45:54.547372
email_sign_in	ArpdnjBbfjgmBcSmxe	\\x41313a322c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54313a722c54393a7265706f72742f31362c	2014-04-25 13:02:07.443783
alert	FMmjjXEjnVSsF6Qd5e	\\x41313a332c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a31302c	2014-04-25 13:02:07.62679
problem	D8wujxAVz44NFLmbgb	\\x41313a352c54383a70617373776f72642c5436303a243261243038244f3170586c6675706e43335a536f4c61477852526b2e49633837726873306e74434342626554705a6b3157633165413674547456472c54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49323a32372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-28 14:18:46.502705
problem	C55aiLGmVMrfG2ZVMU	\\x41313a352c54383a70617373776f72642c5436303a243261243038244f3170586c6675706e43335a536f4c61477852526b2e49633837726873306e74434342626554705a6b3157633165413674547456472c54343a6e616d652c5431313a4572696b61204c757175652c54323a69642c49323a32382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-04-28 15:12:51.887316
problem	DewJRJHDREbXDaCpqU	\\x41313a352c54383a70617373776f72642c5436303a243261243038245559356e3431703647564c79464278464477565176755545307348666e322f7959433064595545374c6939335232535375474378572c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a32392c54353a7469746c652c4e54353a70686f6e652c4931313a35363937333936313733322c	2014-04-28 21:17:38.253356
problem	AekqArB9ddUKAGNEQL	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a33302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-05 20:11:00.970684
problem	FUZjw6GRbHngE2MEF7	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a33312c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-05 20:13:23.786864
problem	CX3E4FBd3ShAAtYscm	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a33322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-05 20:39:26.189543
problem	HCm3FzAeAtNDF7tfFc	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a33332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-05 21:04:27.972251
problem	GaNAhfBfdNdHFXWch9	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a33352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-05 21:28:22.915629
comment	FFTPKfD96a9kAqKRSL	\\x41313a342c54383a70617373776f72642c5436303a243261243038246b6c4570654a4c682e6e33326771744d427253675975745775514a307670304a736738355a3342634669504a766464516c585333652c54343a6e616d652c54363a46656c6970652c54393a6164645f616c6572742c49313a312c54323a69642c49323a31352c	2014-05-06 13:54:52.213067
email_sign_in	BkH9jtD68RpcAyD62r	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-07 14:25:40.426069
email_sign_in	Dthuu3GUtS5JBoaHzv	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-07 14:45:34.43036
email_sign_in	EALyMRFbTwciAnSDBh	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-07 14:47:54.449967
problem	GmMgZnAsrEffB4VEA7	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54323a69642c49323a33372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-07 20:30:49.376226
email_sign_in	EKrKBLBT7asVFNjMUF	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-07 21:12:33.556365
problem	F2juCYBJtBGjBDuTXm	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61206d6f72656c2c54323a69642c49323a33392c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-07 21:31:22.131743
comment	Gme9diCzQzr9EWHFEB	\\x41313a342c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a4d616764616c656e61204d6f72656c2c54393a6164645f616c6572742c49313a312c54323a69642c49323a31372c	2014-05-07 21:32:01.226409
email_sign_in	FMimMPGpjpQGCaGC2P	\\x41313a322c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54313a722c54393a7265706f72742f33382c	2014-05-07 22:02:07.294367
alert	C6vdn8BE7ureBq9qwH	\\x41313a332c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a33302c	2014-05-07 22:02:07.453259
email_sign_in	BLbFdLFUFJjkFkambz	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-07 22:10:30.693954
problem	BFqWUpAsU674CY4WCC	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a34302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-08 23:16:17.968361
email_sign_in	DF5DtnDt4nCJAw8woV	\\x41313a342c54353a656d61696c2c5433313a6f7065726163696f6e657362656c6c61766973746140676d61696c2e636f6d2c54383a70617373776f72642c5436303a243261243038242e667a39306d3735696a34347a30766456557545354f304b48766373615a524c756e436875447a6366386d45587748555851754b4b2c54313a722c54323a6d792c54343a6e616d652c5431313a6f7065726163696f6e65732c	2014-05-09 13:40:44.992335
email_sign_in	EEGjsUGma4CpDjxQzm	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-09 16:22:21.413304
email_sign_in	BWp5vVEKrehtE8mn2P	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54303a2c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-09 18:27:06.586741
problem	FCQRctDM7JKXCJAotx	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a34352c54353a7469746c652c4e54353a70686f6e652c4931313a35363937333936313733322c	2014-05-09 19:35:16.236051
comment	CP5uyMDy7ZTFD6EbeJ	\\x41313a342c54383a70617373776f72642c5436303a2432612430382469724247576e4d50504b66306f2f706c63793437677552594b792e65385a557630764f6830592f73486b42567234416441587366362c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54393a6164645f616c6572742c49313a312c54323a69642c49323a31392c	2014-05-09 20:03:36.61097
questionnaire	CmTUtdF7UBFNE2mnm2	\\x49323a31322c	2014-05-13 18:30:28.202686
questionnaire	AaCLLiDV7BPoBujoXQ	\\x49323a31332c	2014-05-13 19:00:22.277731
questionnaire	Eju6nGEeyQAMF33f8P	\\x49323a31342c	2014-05-13 19:00:22.428167
questionnaire	E8yHiGDTrcJUADWVXB	\\x49323a31352c	2014-05-13 19:30:26.649601
email_sign_in	AyqmtVFuNq2TGC2ddc	\\x41313a342c54353a656d61696c2c5432323a6572696b612e6c757175653840676d61696c2e636f6d2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431313a4572696b61204c757175652c	2014-05-16 14:22:16.345413
problem	EttRcjBdw3RcFvQkQH	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a34372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-16 19:12:23.63365
problem	E8TRQVGEbhZAFwsodQ	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a34382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-16 19:47:16.215569
problem	FiwCUBFQJe5oGQDWAA	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431333a43616d696c61205065726564612c54323a69642c49323a35342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-20 22:01:07.203681
email_sign_in	ADtcN8ALatB5CFStZV	\\x41313a342c54353a656d61696c2c5432343a637269737469616e7175696e74616e61406c6976652e636c2c54383a70617373776f72642c5436303a243261243038245a516f6230435a3775497637616357334c2f576c772e49752f634132654c454977737044786e4150792e584d674b67474353694f472c54313a722c54323a6d792c54343a6e616d652c5432343a637269737469616e7175696e74616e61406c6976652e636c2c	2014-05-21 00:51:41.470888
alert	ENLMbCBHLdEVDyVYxy	\\x41313a332c54353a656d61696c2c5432363a6d6d6f6e74656e6567726f4070726f766964656e6369612e636c2c54343a747970652c54393a7375627363726962652c54323a69642c49323a34362c	2014-05-22 18:44:05.733556
problem	AA3fHkAQnao9C7MDoB	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431343a6a61766965722064656c6761646f2c54323a69642c49323a35362c54353a7469746c652c4e54353a70686f6e652c49383a35353535353535352c	2014-05-23 15:52:10.986466
comment	HH8KZKG6iDrtHBN9wW	\\x41313a342c54383a70617373776f72642c4e54343a6e616d652c5431313a6d6172696f20746f636f6c2c54393a6164645f616c6572742c49313a312c54323a69642c49323a32342c	2014-05-23 15:57:41.595403
email_sign_in	EBVgZwDtENEmBysCrL	\\x41313a322c54353a656d61696c2c5432323a6a64656c6761646f406c6c616e7175696875652e636c2c54313a722c54393a7265706f72742f35362c	2014-05-23 16:02:08.492876
alert	B2HYbgEXWRuhDZuNQA	\\x41313a332c54353a656d61696c2c5432323a6a64656c6761646f406c6c616e7175696875652e636c2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a34372c	2014-05-23 16:02:08.651861
problem	ESafZDA9ZCRgCzMgb6	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431313a6d6172696f20746f636f6c2c54323a69642c49323a35372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-23 16:19:36.391232
problem	AUNx3nGasB5RGvJkTJ	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431323a6d617269746f20746f636f6c2c54323a69642c49323a35382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-23 16:28:25.138625
email_sign_in	FuXATXD2JZwRFMF6Ak	\\x41313a342c54353a656d61696c2c5432353a6f736361726372757a6c697a616e6140676d61696c2e636f6d2c54383a70617373776f72642c5436303a243261243038243470756e47704f2f336a32354f4a7363565433424a4f314d7144396e476433486a7556364f346743624432332f4f556877474366432c54313a722c54323a6d792c54343a6e616d652c5431303a4f73636172204372757a2c	2014-05-25 23:07:06.384902
questionnaire	DmKVetBx4Jk9CPDcdC	\\x49323a31362c	2014-05-26 14:30:31.645633
email_sign_in	CFedAmFDHqvvFTQnXq	\\x41313a342c54353a656d61696c2c5432313a6d6174686961736b6f636840676d61696c2e636f6d2c54383a70617373776f72642c5436303a24326124303824664a4a746c3353653739504d336a3572445a617947654c31667753626d4f4e2f31435156755033453733544273527a65694f5344792c54313a722c54323a6d792c54343a6e616d652c5431323a4d617468696173204b6f63682c	2014-05-26 14:37:55.781125
problem	E98gY8FBvbejG7dNeJ	\\x41313a352c54383a70617373776f72642c5436303a243261243038242e616a5356314670346f6d4f75554658485234703565505468465a53734f42584a52467948374f33464452433449526c2f756a54322c54343a6e616d652c5431333a506164647920436f7274c3a9732c54323a69642c49323a36372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-27 03:47:10.408552
problem	GfxDKmGgTr2pFkWkqP	\\x41313a352c54383a70617373776f72642c5436303a243261243038246e4b38786251374c686c476979433336504f30566d755a4356647365592f586d4c5178733256716d4f75526153505653472e44774b2c54343a6e616d652c5431393a437269737469616e204665726ec3a16e64657a2c54323a69642c49323a36382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-27 16:30:36.560086
problem	CBP6DfBGN9hmBz8yzq	\\x41313a352c54383a70617373776f72642c5436303a2432612430382469724247576e4d50504b66306f2f706c63793437677552594b792e65385a557630764f6830592f73486b42567234416441587366362c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a37322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-29 20:26:23.8882
problem	Ae5t7kFt3EwmHC3gYw	\\x41313a352c54383a70617373776f72642c5436303a24326124303824534e4c6345476a445a4866524b48774576653079764f78393070762e4d507962355a7033322e3558304175347358627163444656572c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a37332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-29 20:39:24.177746
problem	ATtqXND79khLCMm98e	\\x41313a352c54383a70617373776f72642c5436303a24326124303824534e4c6345476a445a4866524b48774576653079764f78393070762e4d507962355a7033322e3558304175347358627163444656572c54343a6e616d652c5431343a46656c69706520416c766172657a2c54323a69642c49323a37352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-29 22:52:07.667098
problem	EmoPc6AfugniA5iyd5	\\x41313a352c54383a70617373776f72642c5436303a2432612430382469724247576e4d50504b66306f2f706c63793437677552594b792e65385a557630764f6830592f73486b42567234416441587366362c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a37362c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-30 15:17:09.128884
problem	F5dqbsBXpQtrB8QACH	\\x41313a352c54383a70617373776f72642c5436303a2432612430382469724247576e4d50504b66306f2f706c63793437677552594b792e65385a557630764f6830592f73486b42567234416441587366362c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a37372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-30 15:28:39.486384
problem	DDokqfC6RUm8Cao2FU	\\x41313a352c54383a70617373776f72642c5436303a243261243038247142317434417058534d392f78716e384d386259394f725444794b4a44552f667237672e777172467646577750756258384f4a772e2c54343a6e616d652c5432393a4361726f6c696e61204865727265726f73205972617272617a6176616c2c54323a69642c49323a37382c54353a7469746c652c4e54353a70686f6e652c49383a37393639363735352c	2014-05-30 20:59:57.28096
problem	CcswRoEBCho9BVb7fA	\\x41313a352c54383a70617373776f72642c5436303a2432612430382469724247576e4d50504b66306f2f706c63793437677552594b792e65385a557630764f6830592f73486b42567234416441587366362c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a37392c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-31 14:45:23.140311
problem	DycjTmBPHDQKBKvuBc	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431323a47696e6f2066616c636f6e652c54323a69642c49323a38302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-31 15:21:08.071028
problem	A79BduBtszNnBTxMtw	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431313a53616e6472612076696c612c54323a69642c49323a38322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-05-31 15:26:57.253128
problem	GNnxz3GkvfNjEzxZaA	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431343a4d6175726963696f2054617069612c54323a69642c49323a38332c54353a7469746c652c4e54353a70686f6e652c54393a3039393637353238322c	2014-06-01 21:08:03.982907
problem	DERu2VCfd7LEEHS4xy	\\x41313a352c54383a70617373776f72642c5436303a24326124303824752e665876337848684b2f33734d4863656172577065594d37782f735243665561715a756d6456434f6c77307764696975383548432c54343a6e616d652c5431323a7061626c6f206775616974612c54323a69642c49323a38352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-01 23:58:04.85363
problem	Ew8pZ8CFFRZ8Dr83gJ	\\x41313a352c54383a70617373776f72642c5436303a243261243038245576786a622f6b58315334536a32415558414933782e514639517865545754316e4e32683633504f52586450782f574857697841472c54343a6e616d652c5431323a7061626c6f206775616974612c54323a69642c49323a38342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-01 23:57:03.959687
comment	ELaFDCGS7fn7ALuBMB	\\x41313a342c54383a70617373776f72642c5436303a243261243038246c5567754c68475462386b37446478315a654d65664f30746e2e322e2f4b3755546e4949383477544e316376737662726f2f5036572c54343a6e616d652c5432323a566572c3b36e69636120646520446f6d7069657272652c54393a6164645f616c6572742c49313a312c54323a69642c49323a32352c	2014-06-03 15:29:10.080809
problem	CFSUPvAfMrKAB9Fa7H	\\x41313a352c54383a70617373776f72642c5436303a24326124303824314d723479424d433759724870384c473842774e6c4f457168463544394a2e57556b4c32564d5874776c4271333037444967344f692c54343a6e616d652c5432313a506564726f204576612d436f6e64656d6172c3ad6e2c54323a69642c49323a38362c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-03 19:19:19.728616
problem	EgfwZ7DTkYwFCj8kNf	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431383a4665726e616e646f20526574616d616c65732c54323a69642c49323a38382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-09 13:54:14.043522
problem	C8LGErDusUnyFmhHP4	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431363a56c3ad63746f722053616176656472612c54323a69642c49323a39312c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-16 04:37:26.12074
questionnaire	FbSXgACbVCMCChDVQS	\\x49323a31372c	2014-06-17 22:30:29.026827
questionnaire	GYVNS7CSx6d2EdnuHd	\\x49323a31382c	2014-06-18 01:30:28.507577
problem	D9Pg2JBvmvQLAkJKPW	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431303a4c756973204261657a612c54323a69642c49323a39322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2014-06-19 14:29:58.701609
comment	GbExipACFFUkGB4DEZ	\\x41313a342c54383a70617373776f72642c54303a2c54343a6e616d652c5431303a4c756973204261657a612c54393a6164645f616c6572742c49313a312c54323a69642c49323a32362c	2014-06-19 15:22:42.547343
questionnaire	ADzXycDu4hPABGRU4g	\\x49323a31392c	2014-06-22 23:30:26.835735
questionnaire	Dr8oYxCkiKK5DRLpKs	\\x49323a32302c	2014-06-23 15:00:21.195666
questionnaire	EgGgp2G7XXTLGrFaKA	\\x49323a32312c	2014-06-23 15:00:21.394814
questionnaire	FttY89GsMPtGBNTk6f	\\x49323a32322c	2014-06-23 15:30:29.254352
questionnaire	AaSZk5Bw6oTVEx5ST4	\\x49323a32332c	2014-06-23 15:30:29.338776
questionnaire	GPUJMkESrC7VEkHC4C	\\x49323a32342c	2014-06-23 15:30:29.412373
questionnaire	Cw664GCWNY4nGtsfnJ	\\x49323a32352c	2014-06-23 16:00:20.811896
questionnaire	Er8Fk9GvhPjwEfvBGx	\\x49323a32362c	2014-06-23 16:00:20.998833
questionnaire	Dtao5vCgt6RyCsJceR	\\x49323a32372c	2014-06-24 04:00:20.572975
questionnaire	ASpoR8FQNbKUAcjR69	\\x49323a32382c	2014-06-24 17:00:22.229742
questionnaire	DGzfabFkGVSqG2sWod	\\x49323a32392c	2014-06-26 19:30:25.182269
email_sign_in	CipWHhGZT3y3FxjAqq	\\x41313a342c54353a656d61696c2c5433333a646761727269646f40636975646164616e6f696e74656c6967656e74652e6f72672c54383a70617373776f72642c5436303a243261243038246659657171476d68324970353732454774316c474c4f587a725a475471476e316d344c784f514b6e4d44697353656c5731375166472c54313a722c54323a6d792c54343a6e616d652c5433323a646761727269646f40636975646164616e6f696e74656c6967656e74652e636c2c	2014-06-26 19:30:49.514073
questionnaire	GPictTADUmDeEEL7Sz	\\x49323a33302c	2014-06-26 20:00:22.134213
questionnaire	A9L78GAQMGbiBAV7cZ	\\x49323a33312c	2014-06-26 20:00:22.229656
questionnaire	BkR5ViCozTnaBUViVe	\\x49323a33322c	2014-06-26 21:30:27.97241
questionnaire	BTjz6aD7wuNyENR7HG	\\x49323a33332c	2014-06-27 21:30:28.367779
questionnaire	BNccViHDMQ2LC8uviz	\\x49323a33342c	2014-06-28 15:00:20.346573
questionnaire	GFf7fpAgxozwE5Abph	\\x49323a33352c	2014-06-28 15:30:25.963607
questionnaire	BCc6EgBV4nRZFkLkeG	\\x49323a33362c	2014-06-29 21:30:28.556305
questionnaire	GyDAJ5GstzHJBYAuyQ	\\x49323a33372c	2014-07-01 19:30:28.08328
alert	CpbgDiCXkm7nHFTbuZ	\\x41313a332c54353a656d61696c2c5432303a6172716d69636166657240676d61696c2e636f6d2c54343a747970652c54393a7375627363726962652c54323a69642c49323a37362c	2014-07-02 02:35:27.551567
questionnaire	DLSPnqBjs6roGhQBsF	\\x49323a33382c	2014-07-02 16:00:22.883031
alert	AdbuY6AZ4PHcAcdMgJ	\\x41313a332c54353a656d61696c2c5433353a726f647269676f5f6f6c6976617265735f746f7272657340686f746d61696c2e636f6d2c54343a747970652c54393a7375627363726962652c54323a69642c49323a37372c	2014-07-03 19:45:55.960154
questionnaire	BM7Y2qGzSnPaEJFxEZ	\\x49323a33392c	2014-07-07 15:00:21.959495
questionnaire	BTRLB3EgYsnVEAaoe3	\\x49323a34302c	2014-07-07 15:00:22.152778
alert	E7bNDdHGiLvpG2Ax8Q	\\x41313a332c54353a656d61696c2c5432343a6a61766965722e726f7665676e6f40676d61696c2e636f6d2c54343a747970652c54393a7375627363726962652c54323a69642c49323a37382c	2014-07-07 19:13:52.725435
questionnaire	F9BWZZDpWUzTEo9QpT	\\x49323a34312c	2014-07-08 23:00:21.615755
questionnaire	FdoxxtBfY73aFVvPNH	\\x49323a34322c	2014-07-14 05:00:22.303799
questionnaire	Dv2DimFKDpMpCfYmtN	\\x49323a34332c	2014-07-17 15:00:21.260399
questionnaire	C7dC26FKcostC9uFiQ	\\x49323a34342c	2014-07-23 17:30:27.539727
questionnaire	DFXVcjGbdzm4ASkhSD	\\x49323a34352c	2014-07-28 00:00:21.53611
questionnaire	BeropiFka7ULEqqcxi	\\x49323a34362c	2014-08-04 17:00:23.091763
questionnaire	E8q2P6AuV4X4G7kit5	\\x49323a34372c	2014-08-11 07:00:21.912972
questionnaire	FUq57KDTDJUdBHPmuo	\\x49323a34382c	2014-08-13 14:30:28.824476
questionnaire	CPGxtNFJpe4PGQT75K	\\x49323a34392c	2014-08-13 14:30:28.972502
questionnaire	BAkvucEz98UQCPPkbr	\\x49323a35302c	2014-09-08 13:30:28.701495
email_sign_in	CrkH3zFVoy7HFmSedj	\\x41313a342c54353a656d61696c2c5431363a676d75726f7040676d61696c2e636f6d2c54383a70617373776f72642c5436303a243261243038247765492f6372516649726b7854334f434369537a67653476432e51786f45686b676356766946664b424864547366717852305769472c54313a722c54323a6d792c54343a6e616d652c54393a476f6e7a616c6f204d2c	2014-10-11 19:05:59.163431
email_sign_in	BLYZJTCqEw2wBvWjQY	\\x41313a342c54353a656d61696c2c5431383a6372616d6972657a4068616e6761722e636c2c54383a70617373776f72642c4e54313a722c54323a6d792c54343a6e616d652c5431383a437269737469c3a16e2052616dc3ad72657a2c	2014-10-24 18:10:55.500356
alert	BxpbiXCse68BGZmgab	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c54393a7375627363726962652c54323a69642c49323a37392c	2015-01-15 15:23:07.553489
alert	CwVYtBBTR7ciAZMWuv	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c54393a7375627363726962652c54323a69642c49323a38302c	2015-01-15 15:29:48.661713
problem	E2mdJoBeGpQmG8wSLf	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a66656c69706520616c766172657a2c54323a69642c49323a39332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-02 21:24:00.668372
email_sign_in	AX9wF4EmxtehAa4aYL	\\x41313a342c54353a656d61696c2c5433303a6d617263656c6f706572657a616e746976696c6f40676d61696c2e636f6d2c54383a70617373776f72642c5436303a2432612430382453385269306a706932686c43634252617252517a4d7547444554464356454b326d4f696c686b6f4c3651362e615975514e672e6c532c54313a722c54323a6d792c54343a6e616d652c5431333a4d617263656c6f20506572657a2c	2015-06-03 15:34:28.955468
problem	BrZp5kANVEdrBWae9j	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431333a44656e697365204d69736c65682c54323a69642c49323a39342c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-03 15:38:05.467029
problem	GLVhLyBtwC8vAvjq2x	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431333a44656e697365204d69736c65682c54323a69642c49323a39352c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-03 15:39:10.348627
alert	BsVbfdFTwzDBCtqyeR	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a37392c	2015-06-03 16:02:07.862575
alert	GkMxawGDeFKTAc2ejY	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a38302c	2015-06-03 16:02:08.203787
alert	AknfRbE6wNZYBMxTib	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a38302c	2015-06-03 22:02:07.3231
problem	DNSQXyGw5bFBEAUeqA	\\x41313a352c54383a70617373776f72642c4e54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49323a39372c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-03 22:08:48.821654
problem	CttGyXGsowbCBER9Tm	\\x41313a352c54383a70617373776f72642c5436303a24326124303824534e4c6345476a445a4866524b48774576653079764f78393070762e4d507962355a7033322e3558304175347358627163444656572c54343a6e616d652c5431373a46656c6970696e776920416c766172657a2c54323a69642c49323a39382c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-04 17:55:17.166532
problem	BwJA7zC2huCDACYVEo	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5433323a46756e64616369c3b36e20436975646164616e6f20496e74656c6967656e74652c54323a69642c49323a39392c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-04 19:03:22.608518
problem	CJXCfGCtKUtBBherrr	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431353a46656c69706520c3816c766172657a2c54323a69642c49333a3130302c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-05 20:26:09.493648
problem	BSnBpSFEGu5FCyN4zJ	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a66656c69706520616c766172657a2c54323a69642c49333a3130312c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-08 19:54:39.401898
problem	FPYZYAGVnwhgCFY6pG	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a66656c69706520616c766172657a2c54323a69642c49333a3130322c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-08 21:53:38.660588
alert	G47jn8FBGL4xErNyDM	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a38302c	2015-06-08 22:02:08.164649
email_sign_in	Avr849BwJ9ufChP2Xe	\\x41313a342c54353a656d61696c2c5433323a6d617263656c6f40636975646164616e6f696e74656c6967656e74652e6f72672c54383a70617373776f72642c5436303a243261243038244c5636384d477064654b344c63796d695a396b792f2e76326b7642316b744c2e64677149624a69664f4e36654b734736716157506d2c54313a722c54323a6d792c54343a6e616d652c5431333a4d617263656c6f20506572657a2c	2015-06-08 22:47:54.567426
problem	AxdzJDEXAUigGYfYAq	\\x41313a352c54383a70617373776f72642c54303a2c54343a6e616d652c5431343a66656c69706520616c766172657a2c54323a69642c49333a3130332c54353a7469746c652c4e54353a70686f6e652c54303a2c	2015-06-09 13:07:51.796428
alert	BnGgeJFpXDa6D6DfVH	\\x41313a332c54353a656d61696c2c5432323a63697564616476697661303140676d61696c2e636f6d2c54343a747970652c5431313a756e7375627363726962652c54323a69642c49323a38302c	2015-06-09 14:02:08.807132
\.


--
-- Data for Name: user_body_permissions; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY user_body_permissions (id, user_id, body_id, permission_type) FROM stdin;
\.


--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('user_body_permissions_id_seq', 1, false);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY users (id, email, name, phone, password, from_body, flagged, title) FROM stdin;
38	denise@ciudadviva.cl	\N	\N		\N	f	\N
39	denimisleh@gmail.com	Denise Misleh	\N		\N	f	\N
6	luisfelipealvarez@gmail.com	Felipe Álvarez		$2a$08$SNLcEGjDZHfRKHwEve0yvOx90pv.MPyb5Zp32.5X0Au4sXbqcDFVW	2	f	\N
40	falvarez@ciudadanoi.org	\N	\N		\N	f	\N
9	falvarez@ciudadanointeligente.org	felipe alvarez	\N		2	f	\N
5	rquijadap@gmail.com	\N	\N		\N	t	\N
41	marcelo@ciudadanointeligente.org	Marcelo Perez	\N	$2a$08$LV68MGpdeK4LcymiZ9ky/.v2kvB1ktL.dgqIbJifON6eKsG6qaWPm	\N	f	\N
4	magda@macleta.cl	Magdalena Morel		$2a$08$RjCXJFaAnsYcPlf4ptYEqOhWbspXOPVut0l8X5AbI332Cn8dxBhzK	\N	f	\N
2	magdamorel@ciudadviva.cl	Magdalena Morel	\N		\N	f	\N
7	jheitmann@uc.cl	\N	\N		\N	f	\N
1	magdamorel@gmail.com	Magdalena Morel			\N	f	\N
3	erika.luque8@gmail.com	Erika Luque		$2a$08$O1pXlfupnC3ZSoLaGxRRk.Ic87rhs0ntCCBbeTpZk1Wc1eA6tTtVG	\N	f	\N
10	operacionesbellavista@gmail.com	Operaciones PB		$2a$08$.fz90m75ij44z0vdVUuE5O0KHvcsaZRLunChuDzcf8mEXwHUXQuKK	\N	f	\N
8	falvarez@votainteligente.cl	Felipe Álvarez		$2a$08$irBGWnMPPKf0o/plcy47guRYKy.e8ZUv0vOh0Y/sHkBVr4AdAXsf6	1	f	\N
11	milapereda@gmail.com	Camila Pereda	\N		\N	f	\N
12	cristianquintana@live.cl	Cristian Quintana Cabrera	85443266	$2a$08$ZQob0CZ7uIv7acW3L/Wlw.Iu/cA2eLEIwspDxnAPy.XMgKgGCSiOG	\N	f	\N
13	mmontenegro@providencia.cl	\N	\N		\N	f	\N
14	jdelgado@llanquihue.cl	javier delgado	55555555		\N	f	\N
15	informatica@llanquihue.cl	marito tocol	\N		\N	f	\N
16	oscarcruzlizana@gmail.com	Oscar Cruz	95975457	$2a$08$4punGpO/3j25OJscVT3BJO1MqD9nGd3HjuV6O4gCbD23/OUhwGCfC	\N	f	\N
17	mathiaskoch@gmail.com	Mathias Koch		$2a$08$fJJtl3Se79PM3j5rDZayGeL1fwSbmON/1CQVuP3E73TBsRzeiOSDy	\N	f	\N
18	paddycortes@yahoo.com	Paddy Cortés	\N	$2a$08$.ajSV1Fp4omOuUFXHR4p5ePThFZSsOBXJRFyH7O3FDRC4IRl/ujT2	\N	f	\N
19	hugo.cristian@gmail.com	Cristian Fernández	\N	$2a$08$nK8xbQ7LhlGiyC36PO0VmuZCVdseY/XmLQxs2VqmOuRaSPVSG.DwK	\N	f	\N
20	carolaherreros@gmail.com	Carolina Herreros Yrarrazaval	79696755	$2a$08$qB1t4ApXSM9/xqn8M8bY9OrTDyKJDU/fr7g.wqrFvFWwPubX8OJw.	\N	f	\N
21	gino@ginofalcone.com	\N	\N		\N	f	\N
22	sandravila@vtr.net	\N	\N		\N	f	\N
23	mt@mauriciotapia.cl	Mauricio Tapia	099675282		\N	f	\N
24	pabloguaita@hotmail.com	\N	\N		\N	f	\N
25	ukadompierre@hotmail.com	\N	\N		\N	f	\N
26	pedevac@yahoo.com	Pedro Eva-Condemarín	\N	$2a$08$1Mr4yBMC7YrHp8LG8BwNlOEqhF5D9J.WUkL2VMXtwlBq307DIg4Oi	\N	f	\N
27	fernando.retamales.l@gmail.com	Fernando Retamales			\N	f	\N
28	vico.saavedra@gmail.com	Víctor Saavedra	\N		\N	f	\N
29	luisantonio.baeza@gmail.com	Luis Baeza	\N		\N	f	\N
30	dgarrido@ciudadanointeligente.org	dgarrido@ciudadanointeligente.cl	\N	$2a$08$fYeqqGmh2Ip572EGt1lGLOXzrZGTqGn1m4LxOQKnMDisSelW17QfG	\N	f	\N
31	arqmicafer@gmail.com	\N	\N		\N	f	\N
32	rodrigo_olivares_torres@hotmail.com	\N	\N		\N	f	\N
33	javier.rovegno@gmail.com	\N	\N		\N	f	\N
34	gmurop@gmail.com	Gonzalo M	\N	$2a$08$weI/crQfIrkxT3OCCiSzge4vC.QxoEhkgcVviFfKBHdTsfqxR0WiG	\N	f	\N
35	cramirez@hangar.cl	Cristián Ramírez	\N		\N	f	\N
36	ciudadviva01@gmail.com	\N	\N		\N	f	\N
37	marceloperezantivilo@gmail.com	Marcelo Perez	\N	$2a$08$S8Ri0jpi2hlCcBRarRQzMuGDETFCVEK2mOilhkoL6Q6.aYuQNg.lS	\N	f	\N
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('users_id_seq', 41, true);


--
-- Name: abuse_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY abuse
    ADD CONSTRAINT abuse_pkey PRIMARY KEY (email);


--
-- Name: admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY admin_log
    ADD CONSTRAINT admin_log_pkey PRIMARY KEY (id);


--
-- Name: alert_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_pkey PRIMARY KEY (id);


--
-- Name: alert_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY alert_type
    ADD CONSTRAINT alert_type_pkey PRIMARY KEY (ref);


--
-- Name: body_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_pkey PRIMARY KEY (id);


--
-- Name: comment_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id);


--
-- Name: contacts_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contacts_history
    ADD CONSTRAINT contacts_history_pkey PRIMARY KEY (contacts_history_id);


--
-- Name: contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: moderation_original_data_comment_id_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_comment_id_key UNIQUE (comment_id);


--
-- Name: moderation_original_data_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_pkey PRIMARY KEY (id);


--
-- Name: partial_user_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY partial_user
    ADD CONSTRAINT partial_user_pkey PRIMARY KEY (id);


--
-- Name: problem_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY problem
    ADD CONSTRAINT problem_pkey PRIMARY KEY (id);


--
-- Name: questionnaire_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_pkey PRIMARY KEY (id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: token_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY token
    ADD CONSTRAINT token_pkey PRIMARY KEY (scope, token);


--
-- Name: user_body_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_pkey PRIMARY KEY (id);


--
-- Name: user_body_permissions_user_id_body_id_permission_type_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_user_id_body_id_permission_type_key UNIQUE (user_id, body_id, permission_type);


--
-- Name: users_email_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: alert_alert_type_confirmed_whendisabled_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_alert_type_confirmed_whendisabled_idx ON alert USING btree (alert_type, confirmed, whendisabled);


--
-- Name: alert_sent_alert_id_parameter_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_sent_alert_id_parameter_idx ON alert_sent USING btree (alert_id, parameter);


--
-- Name: alert_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_user_id_idx ON alert USING btree (user_id);


--
-- Name: alert_whendisabled_cobrand_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_whendisabled_cobrand_idx ON alert USING btree (whendisabled, cobrand);


--
-- Name: alert_whensubscribed_confirmed_cobrand_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_whensubscribed_confirmed_cobrand_idx ON alert USING btree (whensubscribed, confirmed, cobrand);


--
-- Name: body_areas_body_id_area_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX body_areas_body_id_area_id_idx ON body_areas USING btree (body_id, area_id);


--
-- Name: comment_problem_id_created_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_problem_id_created_idx ON comment USING btree (problem_id, created);


--
-- Name: comment_problem_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_problem_id_idx ON comment USING btree (problem_id);


--
-- Name: comment_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_user_id_idx ON comment USING btree (user_id);


--
-- Name: contacts_body_id_category_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX contacts_body_id_category_idx ON contacts USING btree (body_id, category);


--
-- Name: flickr_imported_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX flickr_imported_id_idx ON flickr_imported USING btree (id);


--
-- Name: partial_user_service_email_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX partial_user_service_email_idx ON partial_user USING btree (service, email);


--
-- Name: problem_external_body_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_external_body_idx ON problem USING btree (lower(external_body));


--
-- Name: problem_state_latitude_longitude_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_state_latitude_longitude_idx ON problem USING btree (state, latitude, longitude);


--
-- Name: problem_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_user_id_idx ON problem USING btree (user_id);


--
-- Name: questionnaire_problem_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX questionnaire_problem_id_idx ON questionnaire USING btree (problem_id);


--
-- Name: contacts_insert_trigger; Type: TRIGGER; Schema: public; Owner: fms
--

CREATE TRIGGER contacts_insert_trigger AFTER INSERT ON contacts FOR EACH ROW EXECUTE PROCEDURE contacts_updated();


--
-- Name: contacts_update_trigger; Type: TRIGGER; Schema: public; Owner: fms
--

CREATE TRIGGER contacts_update_trigger AFTER UPDATE ON contacts FOR EACH ROW EXECUTE PROCEDURE contacts_updated();


--
-- Name: admin_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY admin_log
    ADD CONSTRAINT admin_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: alert_alert_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_alert_type_fkey FOREIGN KEY (alert_type) REFERENCES alert_type(ref);


--
-- Name: alert_sent_alert_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert_sent
    ADD CONSTRAINT alert_sent_alert_id_fkey FOREIGN KEY (alert_id) REFERENCES alert(id);


--
-- Name: alert_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: body_areas_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body_areas
    ADD CONSTRAINT body_areas_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: body_comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_comment_user_id_fkey FOREIGN KEY (comment_user_id) REFERENCES users(id);


--
-- Name: body_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_parent_fkey FOREIGN KEY (parent) REFERENCES body(id);


--
-- Name: comment_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: contacts_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: flickr_imported_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY flickr_imported
    ADD CONSTRAINT flickr_imported_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: moderation_original_data_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES comment(id) ON DELETE CASCADE;


--
-- Name: moderation_original_data_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id) ON DELETE CASCADE;


--
-- Name: problem_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY problem
    ADD CONSTRAINT problem_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: questionnaire_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: user_body_permissions_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: user_body_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: users_from_body_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_from_body_fkey FOREIGN KEY (from_body) REFERENCES body(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

