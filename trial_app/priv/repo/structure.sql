--
-- PostgreSQL database dump
--

\restrict 9NaDMne0vvtx0DlijGRMx70UbtcK4F1gjkWWT0ooUBkmD6BrQpEefARGZMQejjq

-- Dumped from database version 14.19 (Ubuntu 14.19-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.19 (Ubuntu 14.19-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_logs (
    id bigint NOT NULL,
    actor_id bigint,
    message text NOT NULL,
    meta jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: activity_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_logs_id_seq OWNED BY public.activity_logs.id;


--
-- Name: announcement_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_links (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    url character varying(255) NOT NULL,
    title character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: announcement_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_links_id_seq OWNED BY public.announcement_links.id;


--
-- Name: announcement_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_reads (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    user_id bigint NOT NULL,
    read_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_reads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_reads_id_seq OWNED BY public.announcement_reads.id;


--
-- Name: announcement_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_targets (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    target_type character varying(255) NOT NULL,
    target_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: announcement_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_targets_id_seq OWNED BY public.announcement_targets.id;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    category character varying(255) NOT NULL,
    priority character varying(255) DEFAULT 'normal'::character varying NOT NULL,
    pinned boolean DEFAULT false,
    publish_date timestamp(0) without time zone NOT NULL,
    expiry_date timestamp(0) without time zone,
    creator_id bigint,
    creator_role character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: announcements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcements_id_seq OWNED BY public.announcements.id;


--
-- Name: attachee_programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachee_programs (
    id bigint NOT NULL,
    attachee_id bigint NOT NULL,
    program_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: attachee_programs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attachee_programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachee_programs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attachee_programs_id_seq OWNED BY public.attachee_programs.id;


--
-- Name: attachees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachees (
    id bigint NOT NULL,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    starts_on date,
    ends_on date,
    user_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    department_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    "position" character varying(255) DEFAULT 'Software Developer Attachee'::character varying
);


--
-- Name: attachees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attachees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attachees_id_seq OWNED BY public.attachees.id;


--
-- Name: daily_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_reports (
    id bigint NOT NULL,
    report_date date NOT NULL,
    summary text,
    tasks_completed text,
    challenges text,
    next_day_plans text,
    status character varying(255) DEFAULT 'draft'::character varying NOT NULL,
    team_lead_id bigint NOT NULL,
    team_id bigint NOT NULL,
    supervisor_id bigint NOT NULL,
    department_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: daily_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_reports_id_seq OWNED BY public.daily_reports.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    organization_id bigint NOT NULL,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    manager_id bigint,
    code character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    supervisor_id bigint
);


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employees (
    id bigint NOT NULL,
    role character varying(255),
    team_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    department_id bigint,
    "position" character varying(255),
    organization_id bigint,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    status character varying(255) DEFAULT 'active'::character varying
);


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluations (
    id bigint NOT NULL,
    score integer,
    comments text,
    attachee_id bigint,
    evaluator_id bigint,
    user_id integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    task_id bigint
);


--
-- Name: evaluations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evaluations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evaluations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evaluations_id_seq OWNED BY public.evaluations.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    code character varying(10)
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    slug character varying(255) NOT NULL,
    description text,
    category character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.positions (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    department_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    user_id bigint
);


--
-- Name: positions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;


--
-- Name: programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.programs (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    code character varying(16),
    is_active boolean DEFAULT true NOT NULL,
    organization_id bigint NOT NULL,
    department_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    starts_on date,
    ends_on date,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL
);


--
-- Name: programs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: programs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.programs_id_seq OWNED BY public.programs.id;


--
-- Name: project_attachees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_attachees (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    attachee_id bigint NOT NULL,
    role character varying(255) DEFAULT 'Intern'::character varying,
    joined_at date,
    left_at date,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: project_attachees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_attachees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_attachees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_attachees_id_seq OWNED BY public.project_attachees.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    code character varying(16),
    is_active boolean DEFAULT true NOT NULL,
    starts_on date,
    ends_on date,
    organization_id bigint NOT NULL,
    department_id bigint NOT NULL,
    program_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    supervisor_id bigint,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id bigint NOT NULL,
    report_type character varying(255) NOT NULL,
    file_path character varying(255),
    file_name character varying(255),
    period_start date,
    period_end date,
    status character varying(255) DEFAULT 'draft'::character varying,
    sent_at timestamp(0) without time zone,
    viewed_at timestamp(0) without time zone,
    summary_data jsonb DEFAULT '{}'::jsonb,
    attachee_id bigint NOT NULL,
    generated_by_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    role_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_system_role boolean DEFAULT false NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: task_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_comments (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    user_id bigint NOT NULL,
    body text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: task_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_comments_id_seq OWNED BY public.task_comments.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    due_on date,
    project_id bigint NOT NULL,
    assignee_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    reject_reason text,
    submitted_at timestamp(0) without time zone,
    created_by_id bigint,
    submission_comment text,
    submission_links character varying(255)[] DEFAULT ARRAY[]::character varying[],
    submission_files character varying(255)[] DEFAULT ARRAY[]::character varying[]
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_members (
    id integer NOT NULL,
    team_id integer NOT NULL,
    user_id integer NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: team_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.team_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: team_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.team_members_id_seq OWNED BY public.team_members.id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    department_id bigint NOT NULL,
    team_lead_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    description text,
    code character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    team_type character varying(255) DEFAULT 'general'::character varying,
    organization_id bigint,
    supervisor_id integer DEFAULT 1 NOT NULL
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: user_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_approvals (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    approved_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_approvals_id_seq OWNED BY public.user_approvals.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(255) NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    assigned_organization_id integer,
    assigned_department_id integer,
    assigned_team_id integer,
    assigned_role character varying(255),
    assigned_position character varying(255),
    team_id bigint,
    must_change_password boolean DEFAULT false NOT NULL,
    password_changed_at timestamp(0) without time zone,
    roles character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    active_role character varying(255) DEFAULT 'attachee'::character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    phone_number character varying,
    user_type character varying(255) DEFAULT 'employee'::character varying,
    organization character varying(255),
    program character varying(255),
    role_id bigint NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    authenticated_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_tokens_id_seq OWNED BY public.users_tokens.id;


--
-- Name: activity_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs ALTER COLUMN id SET DEFAULT nextval('public.activity_logs_id_seq'::regclass);


--
-- Name: announcement_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_links ALTER COLUMN id SET DEFAULT nextval('public.announcement_links_id_seq'::regclass);


--
-- Name: announcement_reads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads ALTER COLUMN id SET DEFAULT nextval('public.announcement_reads_id_seq'::regclass);


--
-- Name: announcement_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_targets ALTER COLUMN id SET DEFAULT nextval('public.announcement_targets_id_seq'::regclass);


--
-- Name: announcements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements ALTER COLUMN id SET DEFAULT nextval('public.announcements_id_seq'::regclass);


--
-- Name: attachee_programs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachee_programs ALTER COLUMN id SET DEFAULT nextval('public.attachee_programs_id_seq'::regclass);


--
-- Name: attachees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachees ALTER COLUMN id SET DEFAULT nextval('public.attachees_id_seq'::regclass);


--
-- Name: daily_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports ALTER COLUMN id SET DEFAULT nextval('public.daily_reports_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: evaluations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations ALTER COLUMN id SET DEFAULT nextval('public.evaluations_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: positions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);


--
-- Name: programs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs ALTER COLUMN id SET DEFAULT nextval('public.programs_id_seq'::regclass);


--
-- Name: project_attachees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_attachees ALTER COLUMN id SET DEFAULT nextval('public.project_attachees_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: task_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments ALTER COLUMN id SET DEFAULT nextval('public.task_comments_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: team_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members ALTER COLUMN id SET DEFAULT nextval('public.team_members_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: user_approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals ALTER COLUMN id SET DEFAULT nextval('public.user_approvals_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens ALTER COLUMN id SET DEFAULT nextval('public.users_tokens_id_seq'::regclass);


--
-- Name: activity_logs activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_pkey PRIMARY KEY (id);


--
-- Name: announcement_links announcement_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_links
    ADD CONSTRAINT announcement_links_pkey PRIMARY KEY (id);


--
-- Name: announcement_reads announcement_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_pkey PRIMARY KEY (id);


--
-- Name: announcement_targets announcement_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_targets
    ADD CONSTRAINT announcement_targets_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: attachee_programs attachee_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachee_programs
    ADD CONSTRAINT attachee_programs_pkey PRIMARY KEY (id);


--
-- Name: attachees attachees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachees
    ADD CONSTRAINT attachees_pkey PRIMARY KEY (id);


--
-- Name: daily_reports daily_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: evaluations evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- Name: programs programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT programs_pkey PRIMARY KEY (id);


--
-- Name: project_attachees project_attachees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_attachees
    ADD CONSTRAINT project_attachees_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: task_comments task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: user_approvals user_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT user_approvals_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: activity_logs_actor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_logs_actor_id_index ON public.activity_logs USING btree (actor_id);


--
-- Name: activity_logs_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_logs_inserted_at_index ON public.activity_logs USING btree (inserted_at);


--
-- Name: announcement_links_announcement_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcement_links_announcement_id_index ON public.announcement_links USING btree (announcement_id);


--
-- Name: announcement_reads_announcement_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX announcement_reads_announcement_id_user_id_index ON public.announcement_reads USING btree (announcement_id, user_id);


--
-- Name: announcement_reads_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcement_reads_user_id_index ON public.announcement_reads USING btree (user_id);


--
-- Name: announcement_targets_announcement_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcement_targets_announcement_id_index ON public.announcement_targets USING btree (announcement_id);


--
-- Name: announcement_targets_target_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcement_targets_target_id_index ON public.announcement_targets USING btree (target_id);


--
-- Name: announcements_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcements_creator_id_index ON public.announcements USING btree (creator_id);


--
-- Name: announcements_pinned_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcements_pinned_index ON public.announcements USING btree (pinned);


--
-- Name: announcements_publish_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcements_publish_date_index ON public.announcements USING btree (publish_date);


--
-- Name: attachee_programs_attachee_id_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX attachee_programs_attachee_id_program_id_index ON public.attachee_programs USING btree (attachee_id, program_id);


--
-- Name: attachees_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachees_department_id_index ON public.attachees USING btree (department_id);


--
-- Name: attachees_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachees_organization_id_index ON public.attachees USING btree (organization_id);


--
-- Name: attachees_user_id_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX attachees_user_id_department_id_index ON public.attachees USING btree (user_id, department_id);


--
-- Name: attachees_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachees_user_id_index ON public.attachees USING btree (user_id);


--
-- Name: daily_reports_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_reports_department_id_index ON public.daily_reports USING btree (department_id);


--
-- Name: daily_reports_report_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_reports_report_date_index ON public.daily_reports USING btree (report_date);


--
-- Name: daily_reports_supervisor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_reports_supervisor_id_index ON public.daily_reports USING btree (supervisor_id);


--
-- Name: daily_reports_team_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_reports_team_id_index ON public.daily_reports USING btree (team_id);


--
-- Name: daily_reports_team_lead_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_reports_team_lead_id_index ON public.daily_reports USING btree (team_lead_id);


--
-- Name: daily_reports_team_lead_team_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX daily_reports_team_lead_team_date_index ON public.daily_reports USING btree (team_lead_id, team_id, report_date);


--
-- Name: departments_manager_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX departments_manager_id_index ON public.departments USING btree (manager_id);


--
-- Name: departments_name_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX departments_name_organization_id_index ON public.departments USING btree (name, organization_id);


--
-- Name: departments_organization_id_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX departments_organization_id_code_index ON public.departments USING btree (organization_id, code) WHERE (code IS NOT NULL);


--
-- Name: departments_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX departments_organization_id_index ON public.departments USING btree (organization_id);


--
-- Name: departments_supervisor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX departments_supervisor_id_index ON public.departments USING btree (supervisor_id);


--
-- Name: departments_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX departments_user_id_index ON public.departments USING btree (user_id);


--
-- Name: employees_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX employees_organization_id_index ON public.employees USING btree (organization_id);


--
-- Name: employees_team_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX employees_team_id_index ON public.employees USING btree (team_id);


--
-- Name: employees_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX employees_user_id_index ON public.employees USING btree (user_id);


--
-- Name: evaluations_attachee_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluations_attachee_id_index ON public.evaluations USING btree (attachee_id);


--
-- Name: evaluations_evaluator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluations_evaluator_id_index ON public.evaluations USING btree (evaluator_id);


--
-- Name: evaluations_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluations_task_id_index ON public.evaluations USING btree (task_id);


--
-- Name: evaluations_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluations_user_id_index ON public.evaluations USING btree (user_id);


--
-- Name: organizations_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizations_code_index ON public.organizations USING btree (code) WHERE (code IS NOT NULL);


--
-- Name: organizations_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizations_name_index ON public.organizations USING btree (name);


--
-- Name: permissions_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_slug_index ON public.permissions USING btree (slug);


--
-- Name: positions_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX positions_department_id_index ON public.positions USING btree (department_id);


--
-- Name: positions_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX positions_name_index ON public.positions USING btree (name);


--
-- Name: positions_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX positions_title_index ON public.positions USING btree (title);


--
-- Name: programs_code_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX programs_code_organization_id_index ON public.programs USING btree (code, organization_id) WHERE (code IS NOT NULL);


--
-- Name: programs_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX programs_department_id_index ON public.programs USING btree (department_id);


--
-- Name: programs_name_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX programs_name_department_id_index ON public.programs USING btree (name, department_id);


--
-- Name: programs_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX programs_organization_id_index ON public.programs USING btree (organization_id);


--
-- Name: project_attachees_attachee_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_attachees_attachee_id_index ON public.project_attachees USING btree (attachee_id);


--
-- Name: project_attachees_project_id_attachee_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX project_attachees_project_id_attachee_id_index ON public.project_attachees USING btree (project_id, attachee_id);


--
-- Name: project_attachees_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_attachees_project_id_index ON public.project_attachees USING btree (project_id);


--
-- Name: projects_code_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_code_organization_id_index ON public.projects USING btree (code, organization_id) WHERE (code IS NOT NULL);


--
-- Name: projects_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_department_id_index ON public.projects USING btree (department_id);


--
-- Name: projects_name_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_name_program_id_index ON public.projects USING btree (name, program_id);


--
-- Name: projects_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_organization_id_index ON public.projects USING btree (organization_id);


--
-- Name: projects_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_program_id_index ON public.projects USING btree (program_id);


--
-- Name: projects_supervisor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_supervisor_id_index ON public.projects USING btree (supervisor_id);


--
-- Name: reports_attachee_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reports_attachee_id_index ON public.reports USING btree (attachee_id);


--
-- Name: reports_generated_by_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reports_generated_by_id_index ON public.reports USING btree (generated_by_id);


--
-- Name: reports_report_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reports_report_type_index ON public.reports USING btree (report_type);


--
-- Name: reports_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reports_status_index ON public.reports USING btree (status);


--
-- Name: role_permissions_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX role_permissions_permission_id_index ON public.role_permissions USING btree (permission_id);


--
-- Name: role_permissions_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX role_permissions_role_id_index ON public.role_permissions USING btree (role_id);


--
-- Name: role_permissions_role_id_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX role_permissions_role_id_permission_id_index ON public.role_permissions USING btree (role_id, permission_id);


--
-- Name: roles_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX roles_name_index ON public.roles USING btree (name);


--
-- Name: task_comments_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_comments_task_id_index ON public.task_comments USING btree (task_id);


--
-- Name: task_comments_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_comments_user_id_index ON public.task_comments USING btree (user_id);


--
-- Name: tasks_assignee_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_assignee_id_index ON public.tasks USING btree (assignee_id);


--
-- Name: tasks_created_by_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_created_by_id_index ON public.tasks USING btree (created_by_id);


--
-- Name: tasks_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_project_id_index ON public.tasks USING btree (project_id);


--
-- Name: team_members_team_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX team_members_team_id_user_id_index ON public.team_members USING btree (team_id, user_id);


--
-- Name: teams_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_department_id_index ON public.teams USING btree (department_id);


--
-- Name: teams_name_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX teams_name_department_id_index ON public.teams USING btree (name, department_id);


--
-- Name: teams_organization_id_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX teams_organization_id_code_index ON public.teams USING btree (organization_id, code) WHERE (code IS NOT NULL);


--
-- Name: teams_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_organization_id_index ON public.teams USING btree (organization_id);


--
-- Name: teams_supervisor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_supervisor_id_index ON public.teams USING btree (supervisor_id);


--
-- Name: teams_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_user_id_index ON public.teams USING btree (team_lead_id);


--
-- Name: unique_announcement_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_announcement_target ON public.announcement_targets USING btree (announcement_id, target_type, target_id);


--
-- Name: user_approvals_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_approvals_user_id_index ON public.user_approvals USING btree (user_id);


--
-- Name: user_approvals_user_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_approvals_user_id_unique ON public.user_approvals USING btree (user_id);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_first_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_first_name_index ON public.users USING btree (first_name);


--
-- Name: users_last_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_last_name_index ON public.users USING btree (last_name);


--
-- Name: users_must_change_password_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_must_change_password_index ON public.users USING btree (must_change_password);


--
-- Name: users_phone_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_phone_number_index ON public.users USING btree (phone_number);


--
-- Name: users_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_role_id_index ON public.users USING btree (role_id);


--
-- Name: users_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_status_index ON public.users USING btree (status);


--
-- Name: users_team_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_team_id_index ON public.users USING btree (team_id);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: users_user_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_user_type_index ON public.users USING btree (user_type);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_index ON public.users USING btree (username);


--
-- Name: activity_logs activity_logs_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: announcement_links announcement_links_announcement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_links
    ADD CONSTRAINT announcement_links_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id) ON DELETE CASCADE;


--
-- Name: announcement_reads announcement_reads_announcement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id) ON DELETE CASCADE;


--
-- Name: announcement_reads announcement_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: announcement_targets announcement_targets_announcement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_targets
    ADD CONSTRAINT announcement_targets_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id) ON DELETE CASCADE;


--
-- Name: announcement_targets announcement_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_targets
    ADD CONSTRAINT announcement_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: announcements announcements_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attachee_programs attachee_programs_attachee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachee_programs
    ADD CONSTRAINT attachee_programs_attachee_id_fkey FOREIGN KEY (attachee_id) REFERENCES public.attachees(id) ON DELETE CASCADE;


--
-- Name: attachee_programs attachee_programs_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachee_programs
    ADD CONSTRAINT attachee_programs_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.programs(id) ON DELETE CASCADE;


--
-- Name: attachees attachees_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachees
    ADD CONSTRAINT attachees_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: attachees attachees_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachees
    ADD CONSTRAINT attachees_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: attachees attachees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachees
    ADD CONSTRAINT attachees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: daily_reports daily_reports_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: daily_reports daily_reports_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: daily_reports daily_reports_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: daily_reports daily_reports_team_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_team_lead_id_fkey FOREIGN KEY (team_lead_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: departments departments_manager_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: departments departments_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: departments departments_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: departments departments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: employees employees_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: employees employees_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: employees employees_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: employees employees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: evaluations evaluations_attachee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_attachee_id_fkey FOREIGN KEY (attachee_id) REFERENCES public.attachees(id);


--
-- Name: evaluations evaluations_evaluator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_evaluator_id_fkey FOREIGN KEY (evaluator_id) REFERENCES public.users(id);


--
-- Name: evaluations evaluations_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;


--
-- Name: evaluations evaluations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teams fk_teams_supervisor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT fk_teams_supervisor FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: positions positions_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: positions positions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: programs programs_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT programs_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: programs programs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT programs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: project_attachees project_attachees_attachee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_attachees
    ADD CONSTRAINT project_attachees_attachee_id_fkey FOREIGN KEY (attachee_id) REFERENCES public.attachees(id) ON DELETE CASCADE;


--
-- Name: project_attachees project_attachees_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_attachees
    ADD CONSTRAINT project_attachees_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: projects projects_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: projects projects_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.programs(id) ON DELETE CASCADE;


--
-- Name: projects projects_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reports reports_attachee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_attachee_id_fkey FOREIGN KEY (attachee_id) REFERENCES public.attachees(id) ON DELETE CASCADE;


--
-- Name: reports reports_generated_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_generated_by_id_fkey FOREIGN KEY (generated_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: task_comments task_comments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_comments task_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_assignee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES public.attachees(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teams teams_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: teams teams_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: teams teams_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_user_id_fkey FOREIGN KEY (team_lead_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE RESTRICT;


--
-- Name: users users_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 9NaDMne0vvtx0DlijGRMx70UbtcK4F1gjkWWT0ooUBkmD6BrQpEefARGZMQejjq

INSERT INTO public."schema_migrations" (version) VALUES (20251023125041);
INSERT INTO public."schema_migrations" (version) VALUES (20251023125054);
INSERT INTO public."schema_migrations" (version) VALUES (20251023125106);
INSERT INTO public."schema_migrations" (version) VALUES (20251023125136);
INSERT INTO public."schema_migrations" (version) VALUES (20251023125148);
INSERT INTO public."schema_migrations" (version) VALUES (20251023162144);
INSERT INTO public."schema_migrations" (version) VALUES (20251023182010);
INSERT INTO public."schema_migrations" (version) VALUES (20251024130412);
INSERT INTO public."schema_migrations" (version) VALUES (20251026085018);
INSERT INTO public."schema_migrations" (version) VALUES (20251026112628);
INSERT INTO public."schema_migrations" (version) VALUES (20251026155021);
INSERT INTO public."schema_migrations" (version) VALUES (20251026174918);
INSERT INTO public."schema_migrations" (version) VALUES (20251027080735);
INSERT INTO public."schema_migrations" (version) VALUES (20251027090421);
INSERT INTO public."schema_migrations" (version) VALUES (20251027120056);
INSERT INTO public."schema_migrations" (version) VALUES (20251027155700);
INSERT INTO public."schema_migrations" (version) VALUES (20251028061804);
INSERT INTO public."schema_migrations" (version) VALUES (20251028064831);
INSERT INTO public."schema_migrations" (version) VALUES (20251028085610);
INSERT INTO public."schema_migrations" (version) VALUES (20251028120000);
INSERT INTO public."schema_migrations" (version) VALUES (20251028120500);
INSERT INTO public."schema_migrations" (version) VALUES (20251030073249);
INSERT INTO public."schema_migrations" (version) VALUES (20251104112932);
INSERT INTO public."schema_migrations" (version) VALUES (20251105100000);
INSERT INTO public."schema_migrations" (version) VALUES (20251105104000);
INSERT INTO public."schema_migrations" (version) VALUES (20251105170143);
INSERT INTO public."schema_migrations" (version) VALUES (20251105191538);
INSERT INTO public."schema_migrations" (version) VALUES (20251106064720);
INSERT INTO public."schema_migrations" (version) VALUES (20251106131622);
INSERT INTO public."schema_migrations" (version) VALUES (20251106135014);
INSERT INTO public."schema_migrations" (version) VALUES (20251106193527);
INSERT INTO public."schema_migrations" (version) VALUES (20251107063050);
INSERT INTO public."schema_migrations" (version) VALUES (20251107072955);
INSERT INTO public."schema_migrations" (version) VALUES (20251107090013);
INSERT INTO public."schema_migrations" (version) VALUES (20251109193505);
INSERT INTO public."schema_migrations" (version) VALUES (20251109194352);
INSERT INTO public."schema_migrations" (version) VALUES (20251109194409);
INSERT INTO public."schema_migrations" (version) VALUES (20251110064408);
INSERT INTO public."schema_migrations" (version) VALUES (20251111070747);
INSERT INTO public."schema_migrations" (version) VALUES (20251114060257);
INSERT INTO public."schema_migrations" (version) VALUES (20251118072515);
INSERT INTO public."schema_migrations" (version) VALUES (20251121025448);
INSERT INTO public."schema_migrations" (version) VALUES (20251121075413);
INSERT INTO public."schema_migrations" (version) VALUES (20251122201106);
INSERT INTO public."schema_migrations" (version) VALUES (20251123111355);
