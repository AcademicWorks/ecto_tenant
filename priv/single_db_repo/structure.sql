--
-- PostgreSQL database dump
--

-- Dumped from database version 15.7
-- Dumped by pg_dump version 15.7

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
-- Name: tenant_bar; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tenant_bar;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: schema_migrations; Type: TABLE; Schema: tenant_bar; Owner: -
--

CREATE TABLE tenant_bar.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: tenant_bar; Owner: -
--

CREATE TABLE tenant_bar.users (
    id bigint NOT NULL,
    name character varying(255)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: tenant_bar; Owner: -
--

CREATE SEQUENCE tenant_bar.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: tenant_bar; Owner: -
--

ALTER SEQUENCE tenant_bar.users_id_seq OWNED BY tenant_bar.users.id;


--
-- Name: users id; Type: DEFAULT; Schema: tenant_bar; Owner: -
--

ALTER TABLE ONLY tenant_bar.users ALTER COLUMN id SET DEFAULT nextval('tenant_bar.users_id_seq'::regclass);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: tenant_bar; Owner: -
--

ALTER TABLE ONLY tenant_bar.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: tenant_bar; Owner: -
--

ALTER TABLE ONLY tenant_bar.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

INSERT INTO tenant_bar."schema_migrations" (version) VALUES (20240721190820);
