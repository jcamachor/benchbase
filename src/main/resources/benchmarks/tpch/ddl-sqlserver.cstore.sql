-- Adapted from the Postgres schema
DROP TABLE IF EXISTS lineitem;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS partsupp;
DROP TABLE IF EXISTS part;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS nation;
DROP TABLE IF EXISTS region;

-- Create date partition function with increment by week.
IF EXISTS(SELECT * FROM sys.partition_schemes WHERE name = 'DatePartitionScheme')
  DROP PARTITION SCHEME DatePartitionScheme;
IF EXISTS(SELECT * FROM sys.partition_functions WHERE name = 'DatePartitionFunction')
  DROP PARTITION FUNCTION DatePartitionFunction;
DECLARE @DatePartitionFunction NVARCHAR(max) =
    N'CREATE PARTITION FUNCTION DatePartitionFunction (DATE)
    AS RANGE LEFT FOR VALUES (';
DECLARE @DateScheme NVARCHAR(max) =
    N'CREATE PARTITION SCHEME DatePartitionScheme
    AS PARTITION DatePartitionFunction TO ('
DECLARE @i DATE = '19920107';
WHILE @i < '19981124'
BEGIN
    SET @DatePartitionFunction += '''' + CAST(@i AS NVARCHAR(10)) + '''' + N', ';
    SET @DateScheme += '[PRIMARY], ';
    SET @i = DATEADD(ww, 1, @i);
END
SET @DatePartitionFunction += '''' + CAST(@i AS NVARCHAR(10))+ '''' + N');';
SET @DateScheme += '[PRIMARY], [PRIMARY]);';
EXEC sp_executesql @DatePartitionFunction;
EXEC sp_executesql @DateScheme;

CREATE TABLE region (
    r_regionkey integer  NOT NULL,
    r_name      char(25) NOT NULL,
    r_comment   varchar(152),
    INDEX region_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (r_regionkey),
    INDEX r_rk UNIQUE (r_regionkey ASC),
);

CREATE TABLE nation (
    n_nationkey integer  NOT NULL,
    n_name      char(25) NOT NULL,
    n_regionkey integer  NOT NULL,
    n_comment   varchar(152),
    INDEX nation_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (n_nationkey),
    INDEX n_nk UNIQUE (n_nationkey ASC),
    INDEX n_rk (n_regionkey ASC),
    FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey)
);

CREATE TABLE part (
    p_partkey     integer        NOT NULL,
    p_name        varchar(55)    NOT NULL,
    p_mfgr        char(25)       NOT NULL,
    p_brand       char(10)       NOT NULL,
    p_type        varchar(25)    NOT NULL,
    p_size        integer        NOT NULL,
    p_container   char(10)       NOT NULL,
    p_retailprice decimal(15, 2) NOT NULL,
    p_comment     varchar(23)    NOT NULL,
    INDEX part_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (p_partkey)
    INDEX p_pk UNIQUE (p_partkey ASC)
);

CREATE TABLE supplier (
    s_suppkey   integer        NOT NULL,
    s_name      char(25)       NOT NULL,
    s_address   varchar(40)    NOT NULL,
    s_nationkey integer        NOT NULL,
    s_phone     char(15)       NOT NULL,
    s_acctbal   decimal(15, 2) NOT NULL,
    s_comment   varchar(101)   NOT NULL,
    INDEX supplier_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (s_suppkey),
    INDEX s_sk UNIQUE (s_suppkey ASC),
    INDEX s_nk (s_nationkey ASC),
    FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey)
);

CREATE TABLE partsupp (
    ps_partkey    integer        NOT NULL,
    ps_suppkey    integer        NOT NULL,
    ps_availqty   integer        NOT NULL,
    ps_supplycost decimal(15, 2) NOT NULL,
    ps_comment    varchar(199)   NOT NULL,
    INDEX partsupp_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (ps_partkey, ps_suppkey),
    INDEX ps_pk (ps_partkey ASC),
    INDEX ps_sk (ps_suppkey ASC),
    INDEX ps_pk_sk UNIQUE (ps_partkey ASC, ps_suppkey ASC),
    INDEX ps_sk_pk UNIQUE (ps_suppkey ASC, ps_partkey ASC),
    FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey),
    FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey)
);

CREATE TABLE customer (
    c_custkey    integer        NOT NULL,
    c_name       varchar(25)    NOT NULL,
    c_address    varchar(40)    NOT NULL,
    c_nationkey  integer        NOT NULL,
    c_phone      char(15)       NOT NULL,
    c_acctbal    decimal(15, 2) NOT NULL,
    c_mktsegment char(10)       NOT NULL,
    c_comment    varchar(117)   NOT NULL,
    INDEX customer_cstore CLUSTERED COLUMNSTORE,
    -- PRIMARY KEY (c_custkey),
    INDEX c_ck UNIQUE (c_custkey ASC),
    INDEX c_nk (c_nationkey ASC),
    FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey)
);

CREATE TABLE orders (
    o_orderkey      integer        NOT NULL,
    o_custkey       integer        NOT NULL,
    o_orderstatus   char(1)        NOT NULL,
    o_totalprice    decimal(15, 2) NOT NULL,
    o_orderdate     date           NOT NULL,
    o_orderpriority char(15)       NOT NULL,
    o_clerk         char(15)       NOT NULL,
    o_shippriority  integer        NOT NULL,
    o_comment       varchar(79)    NOT NULL,
    INDEX o_orderdate_idx CLUSTERED COLUMNSTORE, -- ON DatePartitionScheme(o_orderdate),
    -- PRIMARY KEY (o_orderkey),
    INDEX o_ok UNIQUE (o_orderkey ASC),
    INDEX o_ck (o_custkey ASC),
    INDEX o_od (o_orderdate ASC), -- ON DatePartitionScheme(o_orderdate),
    FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey)
); -- ON DatePartitionScheme(o_orderdate);

CREATE TABLE lineitem (
    l_orderkey      integer        NOT NULL,
    l_partkey       integer        NOT NULL,
    l_suppkey       integer        NOT NULL,
    l_linenumber    integer        NOT NULL,
    l_quantity      decimal(15, 2) NOT NULL,
    l_extendedprice decimal(15, 2) NOT NULL,
    l_discount      decimal(15, 2) NOT NULL,
    l_tax           decimal(15, 2) NOT NULL,
    l_returnflag    char(1)        NOT NULL,
    l_linestatus    char(1)        NOT NULL,
    l_shipdate      date           NOT NULL,
    l_commitdate    date           NOT NULL,
    l_receiptdate   date           NOT NULL,
    l_shipinstruct  char(25)       NOT NULL,
    l_shipmode      char(10)       NOT NULL,
    l_comment       varchar(44)    NOT NULL,
    INDEX l_shipdate_idx CLUSTERED COLUMNSTORE ON DatePartitionScheme(l_shipdate),
    -- PRIMARY KEY (l_orderkey, l_linenumber),
    INDEX l_ok (l_orderkey ASC),
    INDEX l_pk (l_partkey ASC),
    INDEX l_sk (l_suppkey ASC),
    INDEX l_sd (l_shipdate ASC) ON DatePartitionScheme(l_shipdate),
    INDEX l_cd (l_commitdate ASC),
    INDEX l_rd (l_receiptdate ASC),
    INDEX l_pk_sk (l_partkey ASC, l_suppkey ASC),
    INDEX l_sk_pk (l_suppkey ASC, l_partkey ASC),
    FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey),
    FOREIGN KEY (l_partkey, l_suppkey) REFERENCES partsupp (ps_partkey, ps_suppkey)
) ON DatePartitionScheme(l_shipdate);
