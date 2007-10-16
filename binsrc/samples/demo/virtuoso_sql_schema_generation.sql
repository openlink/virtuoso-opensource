DB.DBA.exec_no_error('DROP TABLE thalia.Demo.asu');
    CREATE TABLE thalia.Demo.asu (
        Title LONG VARCHAR NOT NULL,
        Description LONG VARCHAR,
        MoreInfoURL LONG VARCHAR
     );
    
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('100 Principles of Programming with                                  C++. (3)'
                        ,'Principles of problem                                  solving using C++, algorithm design, structured                                  programming, fundamental algorithms and                                  techniques, and computer systems concepts.                                  Social and ethical responsibility. Lecture, lab.                                  Prerequisite: MAT 170. General Studies: CS.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('110 Principles of Programming with                                  Java. (3)'
                        ,'Concepts of problem                                  solving using Java, algorithm design, structured                                  programming, fundamental algorithms and                                  techniques, and computer systems concepts.                                  Social and ethical responsibility. Lecture, lab.                                  Prerequisite: MAT 170.'
                        , 'http://www.eas.asu.edu/~cse110'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('120 Digital Design                                  Fundamentals.(3)'
                        ,'Number systems,                                  conversion methods, binary and complement                                  arithmetic, boolean and switching algebra,                                  circuit minimization. ROMs, PLAs, flipflops,                                  synchronous sequential circuits, and register                                  transfer design. Lecture, lab. Cross-listed with                                  EEE 120. Prerequisite: Computer Literacy.'
                        , 'http://www.eas.asu.edu/~cse120'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('180                                  Computer Literacy.(3)'
                        ,'Introduction to general                                  problem-solving approaches using widely                                  available software tools such as database                                  packages, word processors, spreadsheets, and                                  report generators. May be taken for credit on                                  either IBM PC or Macintosh, but not both.                                  Non-majors only. General Studies : CS.'
                        , 'http://www.eas.asu.edu/~cse180'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('181                                  Applied Problem Solving with Visual BASIC.                                  (3)'
                        ,'Introduction to                                  systematic definition of problems, solution                                  formulation, and method validation. Computer                                  solution using Visual BASIC required for                                  projects. Lecture, lab. Non-majors only.                                  Prerequisite: MAT 117. General Studies: CS.'
                        , 'http://www.eas.asu.edu/~cse181'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('185                                  Internet and the World Wide Web. (3)'
                        ,'Fundamental Internet                                  concepts. World Wide Web browsing, searching,                                  publishing, advanced Internet productivity                                  tools.'
                        , 'http://www.eas.asu.edu/~cse185'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('194 Introduction to Engineering Design.'
                        ,NULL
                        , 'http://www.eas.asu.edu/~hasancam/courses/Spring-2002/ece194/ece194.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('200 Concepts of Computer                                  Science.(3)'
                        ,'Overview of algorithms,                                  architecture, languages, computer systems,                                  theory. Problem solving by programming with a                                  high-level language (Java or another) .                                  Prerequisites: One year of high-school                                  programming with Pascal, C++ or Java; or CSE 100                                  or CSE 110. General Studies: CS.'
                        , 'http://www.eas.asu.edu/~cse200/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('210 Object-Oriented Design and                                  Data Structures.(3)'
                        ,'Object Oriented Design,                                  Static and Dynamic Data Structures (Strings,                                  Stacks, Queues, Binary Trees), Recursion,                                  Searching and Sorting, Professional                                  Responsibility. Prerequisite : CSE 200. General                                  Studies :                                  CS.'
                        , 'http://www.eas.asu.edu/~cse210/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('225 Assembly Language Programming                                  and Microprocessors (Motorola).(4)'
                        ,'Assembly language                                  programming, including input/output programming                                  and exception/interrupt handling. Register-level                                  computer organization, I/O interfaces,                                  assemblers, and linkers. Motorola-based                                  assignments. Lecture, lab. Cross-listed as EEE                                  225. Credit is allowed for only CSE 225 or EEE                                  225. Prerequisites: CSE 100 (or 110 or 200), 120                                  (or EEE 120).'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('226 Assembly Language Programming                                  and Microprocessors (Intel).(4)'
                        ,'CPU/memory/peripheral                                  device interfaces and programming. System buses,                                  interrupts, serial and parallel I/O, DMA,                                  coprocessors. Intel-based assignments. Lecture,                                  lab. Cross-listed as EEE 226. Credit is allowed                                  for only CSE 226 or EEE 226. Prerequisites: CSE                                  100 (or 110 or 200), 120 (or EEE 120).'
                        , 'http://www.eas.asu.edu/~sserc/226/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('240 Introduction to Programming                                  Languages.(3)'
                        ,'Introduces the                                  procedural (C++), applicative (LISP), and                                  declarative (Prolog) languages. Lecture, lab.                                  Prerequisite: CSE 210.'
                        , 'http://www.eas.asu.edu/~cse240/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('300    Intermediate Engineering Design.   (3)'
                        ,NULL
                        , 'http://www.eas.asu.edu/~ece300/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('310 Data Structures and                                  Algorithms. (3)'
                        ,'Advanced data                                  structures and algorithms, including stacks,                                  queues, trees (B, B+, AVL), and graphs.                                  Searching for graphs, hashing and external                                  sorting. Prerequiste: CSE 210, MAT 243.'
                        , 'http://www.eas.asu.edu/~cse310/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('330 Computer Organization and                                  Architecture. (3)'
                        ,'Instruction set                                  architecture, processor performance and design;                                  datapath, control (hardwired, microprogrammed),                                  pipelining, input/output. Memory organization                                  with cache, virtual memory. Prerequisite:                                  CSE/EEE 225 or CSE/EEE 226.'
                        , 'http://www.eas.asu.edu/~cse330/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('340 Principles of Programming                                  Languages. (3)'
                        ,'Introduction to                                  language design and implementation. Parallel,                                  machine dependent and declarative language                                  features; type theory; specification,                                  recognition, translation, run-time management.                                  Prerequisites: CSE 240, CSE 310, CSE/EEE 225 or                                  226.'
                        , 'http://www.eas.asu.edu/~cse340/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('355 Introduction to Theoretical                                  Computer Science.(3)'
                        ,'Introduction to formal                                  language theory and automata, Turing machines,                                  decidability/undecidability, recursive function                                  theory, and introduction to complexity theory.                                  Prerequisite: CSE 310.'
                        , 'http://www.eas.asu.edu/~cse355/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('360 Introduction to Software                                  Engineering. (3)'
                        ,'Software life cycle                                  models; Project management, team development,                                  environments and methodologies; software                                  architectures; quality assurance and standards;                                  legal, ethical issues. Prerequisite: CSE 240 and                                  CSE 210.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('408                                  Multimedia Information Systems.(3)'
                        ,'Design, use, and                                  applications of multimedia systems. An                                  introduction to acquisition, compression,                                  storage, retrieval, and presentation of data                                  from different media such as images, text,                                  voice, and alphanumeric. Prerequisite: CSE 310.'
                        , 'http://www.eas.asu.edu/~cse408/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('412 Database Management. (3)'
                        ,'Introduction to DBMS                                  concepts. Data models and languages. Relational                                  database theory. Database security/ integrity                                  and concurrency. Prerequisite: CSE 310.'
                        , 'http://www.eas.asu.edu/~cse412/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('420 Computer Architecture                                  I. (3)'
                        ,'Computer architecture.                                  Performance versus cost trade-offs. Instruction                                  set design. Basic processor implementation and                                  pipelining. Prerequisite: CSE 330.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('421 Microprocessor System Design                                  I.(4)'
                        ,'Assembly-language                                  programming and logical hardware design of                                  systems using 8-bit microprocessors and                                  micro-controllers. Fundamental concepts of                                  digital system design. Reliability and social,                                  legal implications. Lecture, lab. Prerequisite:                                  CSE/EEE 225.'
                        , 'http://www.eas.asu.edu/~cse421/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('422 Microprocessor System Design                                  II.(4)'
                        ,'Design of microcomputer                                  systems using contemporary logic and                                  microcomputer system components. Requires                                  assembly language programming. Prerequisite: CSE                                  421.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('423 Microcomputer System                                  Hardware.(3)'
                        ,'Information and                                  techniques presented in CSE 422 are used to                                  develop the hardware design of a microprocessor,                                  multiprogramming, microprocessor-based system.                                  Prerequisite: CSE 422. General Studies.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('428                                  Computer-Aided Processes.(3)'
                        ,'Hardware and software                                  considerations for computerized manufacturing                                  systems. Specific concentration on automatic                                  inspection, numerical control, robotics, and                                  integrated manufacturing systems. Prerequisite:                                  CSE 330.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('430 Operating Systems.(3)'
                        ,'Operating system                                  structure and services, processor scheduling,                                  concurrent processes, synchronization                                  techniques, memory management, virtual memory,                                  input/output, storage management, file systems.                                  Prerequisites: CSE 330, 340.'
                        , 'http://www.eas.asu.edu/~cse430/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('432 Operating System                                  Internals.(3)'
                        ,'IPC, exception and                                  interrupt processing, memory and thread                                  management, user-level device drivers, and OS                                  servers in a modern microkernel-based OS.                                  Prerequisite: CSE 430.'
                        , 'http://www.eas.asu.edu/~cse432/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('434                                  Computer Networks.(3)'
                        ,'Physical layer basics;                                  network protocol algorithms; error handling;                                  flow control; multihop routing; network                                  reliability, timing, security; data compression;                                  cryptography fundamentals. Prerequisite: CSE 330'
                        , 'http://www.eas.asu.edu/~cse434/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('438 Systems Programming.(3)'
                        ,'Design and                                  implementtion of systems programs, including                                  text editors, file utilities, monitors,                                  assemblers, relocating linking loaders, I/O                                  handlers, schedulers, etc. Prerequisite: CSE 421                                  or instructor approval. General Studies: L'
                        , 'http://www.eas.asu.edu/~cse438/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('440 Compiler Construction                                  I. (3)'
                        ,'Introduction to                                  programming language implementation.                                  Implementation strategies such as compilation,                                  interpretation, and translation. Major                                  compilation phases such as lexical analysis,                                  semantic analysis, optimization, and code                                  generation. Prerequisites: CSE 340, 355.'
                        , 'http://www.eas.asu.edu/~cse440/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('445 Distributed Computing with Java                                  and CORBA.(3)'
                        ,'Frameworks for                                  distributed software components. Foundations of                                  client-server computing and architectures for                                  distributed object systems. Dynamic discovery                                  and invocation. Prerequisites: CSE 360.'
                        , 'http://www.eas.asu.edu/~cse445/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('446 Client-Server User                                  Interfaces.(3)'
                        ,'Client-server model for                                  creating window interfaces. Toolkits and                                  libraries such as X11, Microsoft Foundation                                  Classes and Java Abstract Window Toolkit.                                  Prerequisites: CSE 310.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('450 Design and Analysis of                                  Algorithms.(3)'
                        ,'Design and analysis of                                  computer algorithms using analytical and                                  empirical methods; complexity measures, design                                  methodologies, and survey of important                                  algorithms. Prerequisite: CSE 310.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('457 Theory of Formal                                  Languages. (3)'
                        ,'Theory of grammar,                                  methods of syntactic analysis and specification,                                  types of artificial languages, relationship                                  between formal languages, and automata.                                  Cross-listed as MAT 401. Prerequisite: CSE 355.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('459                                  Logic for Computing Scientists. (3)'
                        ,'Propositional logic,                                  syntax and semantics, proof theory vs. model                                  theory, soundness, consistency and completeness,                                  first order logic, logical theories, automated                                  theorem proving, ground resolution, pattern                                  matching unification and resolution, Dijkstras                                  logic, proof obligations, and program proving.                                  Prerequisite: CSE 355.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('460 Software Analysis and                                  Design. (3)'
                        ,'Software engineering                                  foundations, formal representations in the                                  software process; use of formalisms in creating                                  a measured and structured working environment.                                  Prerequisite: CSE 360.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('461 Software Engineering Project                                  I.(3)'
                        ,'First of 2-course                                  software design sequence. Development planning,                                  management; process modeling; incremental and                                  team development using CASE tools. Prerequisite:                                  CSE 360.'
                        , 'http://www.eas.asu.edu/~cse461/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('462 Software Engineering Project                                  II.(3)'
                        ,'Second of 2-course                                  software design sequence. Process, product assessment and                                  improvement; incremental and team development                                  using CASE tools. Prerequisite: CSE 461.'
                        , 'http://www.eas.asu.edu/~cse462/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('470                                  Computer Graphics. (3)'
                        ,'Display devices, data                                  structures, transformation, interactive                                  graphics, 3-dimensional graphics, and hidden                                  line problem. Prerequisites: CSE 310; MAT 342.'
                        , 'http://www.eas.asu.edu/~cse470/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('471 Introduction to Artificial                                  Intelligence.(3)'
                        ,'State space search,                                  heuristic search, games, knowledge                                  representation techniques, expert systems, and                                  automated reasoning. Prerequisite: CSE 240, 310.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('473                                  Nonprocedural Programming Languages. (3)'
                        ,'Functional and logic                                  programming using languages like Lucid and                                  Prolog. Typical applications would be a Screen                                  Editor and an Expert System. Prerequisite: CSE                                  355.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('476 Introduction to Natural                                  Language Processing. (3)'
                        ,'Principles of                                  computational linguistics, formal syntax, and                                  semantics, as applied to the design of software                                  with natural (human) language I/O. Prerequisite:                                  CSE 310 or instructor approval.'
                        , 'http://www.eas.asu.edu/~cse476/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('477                                  Introduction to Computer-Aided Geometric                                  Design.(3)'
                        ,'Introduction to                                  parametric curves and surfaces. Bezier and                                  B-spline interpolation, and approximation                                  techniques. Prerequisites: CSE 210, CSE 470; MAT                                  342.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494 Advanced Database                                  Concepts.(3)'
                        ,'Advanced data modeling,                                  object-oriented databases, and object-relational                                  databases. Web access to databases.                                  Professionalism and ethics in information                                  access. Credit: 3 hours. Prerequisite: CSE 412'
                        , 'http://www.eas.asu.edu/~cse494db'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494 Building and                                  programming mobile robots.(3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~cbaral/cse494-f00/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494                                  Information Retrieval, Mining and Integration on                                  the Internet.(3)'
                        ,NULL
                        , 'http://rakaposhi.eas.asu.edu/cse494/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494 Principles                                  of Information Engineering.(3)'
                        ,'Train computer science                                  students to be effective information specialists                                  with an entrepreneurial perspective and                                  managerial outlook.'
                        , 'http://ceaspub.eas.asu.edu/cse494b/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494/598 Wireless                                  Sensor Networks(3)'
                        ,'Applications (pervasive                                  computing, health-monitoring, home land                                  security), data dissemination and aggregation,                                  security, localization, time synchronization,                                  energy-efficiency, reliability, programming                                  platforms.'
                        , 'http://shamir.eas.asu.edu/~mcn/cse494sp05.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('494 Real-Time Embedded Systems.                                  (3)'
                        ,NULL
                        , 'http://rts-lab.eas.asu.edu/courses/cse494/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('507 Virtual Reality Systems.(3)'
                        ,'Computer generated 3-D                                  environments, spatial presence of virtual                                  objects, technologies of immersion, tracking                                  systems, simulation of reality. Prerequisites:                                  CSE 408 or CSE 508 or CSE 470 or instructor                                  approval.'
                        , 'http://www.eas.asu.edu/~cse507/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('508 Digital Image Processing.(3)'
                        ,'Digital image                                  fundamentals, image transforms, image                                  enhancement and restoration techniques, image                                  encoding, and segmentation methods.                                  Prerequisite: EEE 303 or instructor approval.'
                        , 'http://www.eas.asu.edu/~cse508/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('510                                  Database Management System                                  Implementation.(3)'
                        ,'Implementation of                                  database systems. Data storage, indexing,                                  querying, and retrieval. Query optimization and                                  execution, concurrency control, and transaction                                  management. Prerequisite: CSE 412.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('512 Distributed Database                                  Systems.(3)'
                        ,'Distributed database                                  design, query processing, and transaction                                  processing. Distributed database architectures                                  and interoperability. Emerging technology.                                  Prerequisite: CSE 412.'
                        , 'http://www.eas.asu.edu/~cse512/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('513                                  Rules inDatabase Systems.(3)'
                        ,'Declarative and active                                  rules. Logic as a data model. Evaluation and                                  query optimization. Triggers and ECA rules.                                  Current research topics. Prerequisite: CSE 412.'
                        , 'http://www.eas.asu.edu/~cse513/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('514                                  Object-Oriented Database Systems.(3)'
                        ,'Object-oriented data                                  modeling, database and language integration,                                  object algebras, extensibility, transactions,                                  object managers, versioning/configuration,                                  active data, nonstandard applications. Research                                  seminar. Prerequisite: CSE 510.'
                        , 'http://www.eas.asu.edu/~cse514/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('515 Multimedia                                  and Web Databases. (3)'
                        ,'Data models for                                  multimedia and Web data; query processing and                                  optimization for inexact retrieval; advanced                                  indexing, clustering, and search techniques.                                  Prerequisites: CSE 408, 412.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('517                                  Hardware Design Languages. (3)'
                        ,'Introduction to                                  hardware design languages using VHDL. Modeling                                  concepts for specification, simulation,                                  synthesis.. Prerequisite: CSE 423 or EEE 425 or                                  consent of instructor.'
                        , 'http://www.eas.asu.edu/~cse517/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('518                                  Synthesis with Hardware Design                                  Languages.(3)'
                        ,'Modeling VLSI design in                                  hardware design languages for synthesis.                                  Transformation of language-based designs to                                  physical layout. Application of synthesis tools.                                  Prerequisite: CSE 517.'
                        , 'http://www.eas.asu.edu/~cse518/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('520 Computer Architecture II.(3)'
                        ,'Computer architecture                                  description languages, computer arithmetic,                                  memory-hierarchy design, parallel, vector, and                                  multiprocessors, and input/output..                                  Prerequisites: CSE 420, 430.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('521 Microprocessor Applications.(4)'
                        ,'Microprocessor                                  technology and its application to the design of                                  practical digital systems. Hardware, assembly                                  language programming, and interfacing of                                  microprocessor-based systems. Lecture, lab.                                  Prerequisite: CSE 421.'
                        , 'http://www.eas.asu.edu/~cse521/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('523 Microcomputer Systems                                  Software.(3)'
                        ,'Developing system                                  software for a multiprocessor, multiprogramming,                                  microprocessor-based system using information                                  and techniques presented in CSE 421, 422.                                  Prerequisite: CSE 422.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('526 Parallel Processing.(3)'
                        ,'Real and apparent                                  concurrency. Hardware organization of                                  multiprocessors, multiple computer systems,                                  scientific attached processors, and other                                  parallel systems. Prerequisite: CSE 330 or 423.'
                        , 'http://www.eas.asu.edu/~cse526/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('530 Operating System Case Study.(3)'
                        ,'Study of the design and                                  implementation of a timeshared multiprogramming                                  operating system, with emphasis on the UNIX                                  operating system. Prerequisites: CSE 430;                                  knowledge of C Language.'
                        , 'http://www.eas.asu.edu/~cse530/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('531 Distributed and Multiprocessor                                  Operating Systems.(3)'
                        ,'Distributed systems                                  architecture, remote file access, message-based                                  systems, object-based systems, client/server                                  paradigms, distributed algorithms, replication                                  and consistency, and multiprocessor operating                                  systems. Prerequisite: CSE 432 or instructor                                  approval.'
                        , 'http://cactus.eas.asu.edu/partha/Teaching/531.2002/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('532 Advanced Operating System                                  Internals.(3)'
                        ,'Memory, processor,                                  process and communication management, and                                  concurrency control in the Windows NT                                  multiprocessor and distributed operating system                                  kernel and servers. Prerequisite: CSE 530 and                                  either CSE 531 or CSE 536.'
                        , 'http://www.eas.asu.edu/~cse532/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('534 Advanced Computer Networks.(3)'
                        ,'Advanced network                                  protocols and infrastructure, applications of                                  high-performance networks to distributed                                  systems, high-performance computing and                                  multimedia domains, special features of                                  networks: real-time, security, reliability.                                  Prerequisite: CSE 434.'
                        , 'http://www.eas.asu.edu/~cse534/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('536 Advanced Operating Systems.(3)'
                        ,'Protection and file                                  systems. Communication, processes,                                  synchronization, naming, fault tolerance,                                  security, data replication, and coherence in                                  distributed systems. Real-time systems.                                  Prerequisite: CSE 430.'
                        , 'http://www.eas.asu.edu/~cse536s2/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('537 ATM Networks.(3)'
                        ,'Principles of ATM                                  networks, switch architecture, traffic                                  management, call and connection control,                                  routing, internetworking with ATM networks,                                  signaling, and OAM. Prerequisite: CSE 434.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('539 Applied Cryptography.(3)'
                        ,'Use of cryptography for                                  secure protocols over networked systems,                                  including signatures, certificates, timestamps,                                  electrons, digital cash, and other multiparty                                  coordination. Prerequisite: CSE 310 or                                  instructor approval.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('540 Compiler Construction II.(3)'
                        ,'Formal parsing                                  strategies, optimization techniques, code                                  generation, extensibility and transportability                                  considerations, and recent developments.                                  Prerequisite: CSE 440.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('545 Programming Language Design.(3)'
                        ,'Language constructs,                                  extensibility and abstractions, and runtime                                  support. Language design process. Prerequisite:                                  CSE 440.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('550                                  Combinatorial Algorithms and                                  Intractability.(3)'
                        ,'Combinatorial                                  algorithms, nondeterministic algorithms, classes                                  P and NP, NP-hard and NP-complete problems, and                                  intractability. Design techniques for fast                                  combinatorial algorithms. Prerequisite: CSE 450.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('555 Theory of Computation.(3)'
                        ,'Rigorous treatment of                                  regular languages, context-free languages,                                  Turing machines and decidability, reducibility,                                  and other advanced topics in computability                                  theory. Prerequisite: CSE 355.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('556                                  Expert Systems.(3)'
                        ,'Knowledge acquisition                                  and representation, rule-based systems,                                  frame-based system, validation of knowledge                                  bases, inexact reasoning, and expert database                                  systems.Prerequisite CSE 471.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('562                                  Software Process Automation.(3)'
                        ,'Software engineering                                  characteristics particular to parallel and                                  distributed systems. Tools and techniques to                                  support software engineering involving parallel                                  processing and distributed systems.                                  Prerequisite: CSE 360.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('563                                  Software Requirements and                                  Specification. (3)'
                        ,'Examination of the                                  definitional stage of software development;                                  analysis of specification representations and                                  techniques emphasizing important application                                  issues. Prerequisite: CSE 460.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('564                                  Software Design. (3)'
                        ,'Examination of software                                  design issues and techniques. Includes a survey                                  of design representations and a comparison of                                  design methods. Prerequisite: CSE 460.'
                        , 'http://www.eas.asu.edu/~cse564/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('565 Software Verification,                                  Validation and Testing.(3)'
                        ,'Test planning;                                  requirements-based and code-based testing                                  techniques; tools; reliability models;                                  statistical testing. Prerequisite: CSE 460.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('566 Software Project, Process and                                  Quality Management.(3)'
                        ,'Project Management,                                  risk management, configuration management,                                  quality management, simulated project management                                  experience. Prerequisite: CSE 460.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('570                                  Advanced Computer Graphics I.(3)'
                        ,'Hidden surface                                  algorithms, lighting models, and shading                                  techniques. User interface design. Animation                                  techniques. Fractals and stochastic models.                                  Raster algorithms. Prerequisite: CSE 470.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('571                                  Artificial Intelligence.(3)'
                        ,'Definitions of                                  intelligence, computer problem solving, game                                  playing, pattern recognition, theorem proving,                                  and semantic information processing;                                  evolutionary systems; heuristic programming.                                  Prerequisite: CSE 471.'
                        , 'http://www.public.asu.edu/~cbaral/cse571-f99/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('573 Advanced Computer Graphics II.                                  (3)'
                        ,'Modeling of natural                                  phenomena: terrain, clouds, fire, water, and                                  trees. Particle systems, deformation of solids,                                  antialiasing, adn volume visualization. Lecture,                                  Lab. Prerequisite: CSE 470.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('574 Planning and Learning Methods                                  in AI.(3)'
                        ,'Reasoning about time                                  and action, plan synthesis and execution,                                  improving planning performance, applications to                                  manufacturing intelligent agents. Prerequisite:                                  CSE 471.'
                        , 'http://rakaposhi.eas.asu.edu/cse574'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('575                                  Decision-Making Strategies in AI.(3)'
                        ,'Automatic knowledge                                  acquisition, automatic analysis/synthesis of                                  strategies, distributed planning/ problem                                  solving, casual modeling, predictive                                  human-machine environments. Prerequisite: CSE                                  571.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('576 Topics in                                  Natural Language Processing.(3)'
                        ,'Comparative parsing                                  strategies, scooping and reference problems,                                  nonfirst-order logical semantic representations,                                  and discourse structure. Prerequisite: CSE 476.'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('577                                  Advanced Computer-Aided Geometric Design                                  I.(3)'
                        ,'General interpolation;                                  review of curve interpolation and approximation;                                  spline curves; visual smoothness of curves;                                  parameterization of curves; introduction to                                  surface interpolation and approximation.                                  Prerequisites: CSE 470 and 477.'
                        , 'http://eros.cagd.eas.asu.edu/~farin/classes/cse577/cse577.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('578                                  Advanced Computer-Aided Geometric Design II.                                  (3)'
                        ,'Coons patches and                                  Bezier patches; triangular patches; arbitrarily                                  located data methods; geometry processing of                                  surfaces; higher dimensional surfaces.                                  Prerequisites: CSE 470 and 477.'
                        , 'http://eros.cagd.eas.asu.edu/~farin/classes/cse578/cse578.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('579 NURBs:                                  Nonuniform Rational B-Splines.(3)'
                        ,'Projective geometry,                                  NURBs-based modeling, basic theory of conics and                                  rational surfaces, stereographic maps, quadrics,                                  IGES data specification. Prerequisites: CSE 470                                  and 477.'
                        , 'http://eros.cagd.eas.asu.edu/~farin/classes/cse579/cse579.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591                                  Advanced Topics on Parallel and Distributed                                  Computing. (3)'
                        ,NULL
                        , 'http://www.eas.asu.edu/~cse591os'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Autonomous                                  Agents: theory and practice. (3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~cbaral/cse591-f01/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Computational Algorithms for                                  Systems Biology. (3)'
                        ,NULL
                        , 'http://www.eas.asu.edu/~csedept/courses/591_computational.htm'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591                                  Computational Molecular Biology. (3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~cbaral/cse591-s03/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Data Mining.                                  (3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~huanliu/cse591.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591                                  Hardware-Software Co-design. (3)'
                        ,NULL
                        , 'http://cse.asu.edu/~cse591b/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Image                                  Processing-II Digital Video processing. (3)'
                        ,NULL
                        , 'http://www.eas.asu.edu/~cse591f/'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Mobile Ad                                  Hoc Networking  Computing. (3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~syrotiuk/cse591/index.html'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Mobile                                  Computing. (3)'
                        ,NULL
                        , 'http://shamir.eas.asu.edu/~cse591tv'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Object                                  Oriented Modeling  Simulation. (3)'
                        ,NULL
                        , 'http://www.eas.asu.edu/~hsarjou/Courses/CSE591fall02.pdf'
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Practical                                  Operating System Internals. (3)'
                        ,NULL
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591 Randomized                                  and Approximation Algorithms. (3)'
                        ,NULL
                        , NULL
        );
    
        INSERT INTO thalia.Demo.asu (Title,Description,MoreInfoURL)
        VALUES ('591                                  Semantic Web Mining. (3)'
                        ,NULL
                        , 'http://www.public.asu.edu/~hdavulcu/CSE591_Semantic_Web_Mining.html'
        );
    



DB.DBA.exec_no_error('DROP TABLE thalia.Demo.brown');
CREATE TABLE thalia.Demo.brown (
        Code VARCHAR(8) NOT NULL UNIQUE, 
        Title LONG VARCHAR NOT NULL,
        Instructor LONG VARCHAR,
        Room LONG VARCHAR
)
;
    
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS002'
                        ,'"http://www.cs.brown.edu/courses/cs002/" Concepts                     Challenges of CS  C hr. MWF 10-11'
                        ,'"http://www.cs.brown.edu/~dls/" Stanford'
                        , 'Salomon 001'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS004'
                        ,'"http://www.cs.brown.edu/courses/cs004/" Intro to                    Scientific Computing  K hr. T,Th 2:30-4'
                        ,'"http://www.cs.brown.edu/~ausas/" Usas'
                        , 'MacMillan 117'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS016'
                        ,'"http://www.cs.brown.edu/courses/cs016/" Intro to                    Algorithms  Data Structures  D hr. MWF 11-12'
                        ,'"http://www.cs.brown.edu/~rt/" Tamassia'
                        , 'CIT Lubrano'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS018'
                        ,'"http://www.cs.brown.edu/courses/cs018/" CS: An                    Integrated Approach  J hr. T,Th 1-2:30'
                        ,'"http://www.cs.brown.edu/~klein/" Klein'
                        , 'CIT 227'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS022'
                        ,'"http://www.cs.brown.edu/courses/cs022/" Intro. to                    Discrete Mathematics  B hr. MWF 9-10'
                        ,'"http://www.cs.brown.edu/~anna/" Lysyanskaya'
                        , 'CIT 165'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS032'
                        ,'"http://www.cs.brown.edu/courses/cs032/" Intro. to                    Software Engineering  K hr. T,Th 2:30-4'
                        ,'"http://www.cs.brown.edu/~spr/" Reiss'
                        , 'CIT 165, Labs in Sunlab'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS034'
                        ,'"http://www.cs.brown.edu/courses/cs034/" Intro. to                    Systems Programming  THURSDAY ONLY 1-2:30'
                        ,'"http://www.cs.brown.edu/~er/" Manos                  Renieris'
                        , 'TBA'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS92'
                        ,''
                        ,'"http://www.cs.brown.edu/~rbb/" Blumberg'
                        , 'Educational Software Seminar K hr. T,Th 2:30-4'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CIT 506'
                        ,''
                        ,NULL
                        , NULL
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS138'
                        ,'"http://www.cs.brown.edu/courses/cs138/" Networked                    Information Systems  I hr. T,Th 10:30-12'
                        ,'"http://www.cs.brown.edu/~ugur/" Cetintemel'
                        , 'CIT 368'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS141'
                        ,'"http://www.cs.brown.edu/courses/cs141/" Intro. to                    Artificial Intelligence  I hr. T,Th 10:30-12'
                        ,'"http://www.cs.brown.edu/~amygreen/" Greenwald'
                        , 'CIT 227'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS148'
                        ,'"http://www.cs.brown.edu/courses/cs148/" Building                    Intelligent Robots  H hr. T,Th 9-10:30'
                        ,'"http://www.cs.brown.edu/~ec/" Charniak'
                        , 'CIT 368'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS155'
                        ,'"http://www.cs.brown.edu/courses/cs155/" Probabilistic                    Methods in CS  J hr. T,Th 1-2:30'
                        ,'"http://www.cs.brown.edu/~eli/" Upfal'
                        , 'CIT 506'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS168'
                        ,'"http://www.cs.brown.edu/courses/cs168/" Computer                    Networks  M hr. M 3-5:30'
                        ,'"http://www.cs.brown.edu/~twd/" Doeppner'
                        , 'CIT 368'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS181'
                        ,'"http://www.cs.brown.edu/courses/cs181/" Computational                    Molecular Biology  K hr. T,Th 2:30-4'
                        ,'"http://www.cs.brown.edu/~franco/" Preparata'
                        , 'CIT 368'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS190'
                        ,'"http://www.cs.brown.edu/courses/cs190/" Software                    System Design  D hr. MWF 11-12'
                        ,'"http://www.cs.brown.edu/~sk/" Krishnamurthi'
                        , 'CIT 368'
)
;
    
INSERT INTO thalia.Demo.brown (Code,Title,Instructor,Room)
 VALUES ('CS196-9'
                        ,'"http://www.cs.brown.edu/courses/cs196-9/" Document                    Engineering  H hr. T,Th 9-10:30'
                        ,'"http://www.cs.brown.edu/~dgd/" Durand'
                        , 'CIT 506'
)
;


DB.DBA.exec_no_error('DROP TABLE thalia.Demo.cmu');
    CREATE TABLE thalia.Demo.cmu (
        Code VARCHAR(16) NOT NULL, -- not unique really ;)
        Sec VARCHAR(2),
        CourseXListed LONG VARCHAR,
        CourseTitle LONG VARCHAR NOT NULL,
        Lecturer LONG VARCHAR,
        Room LONG VARCHAR,
        Day_ LONG VARCHAR,
        Time_ LONG VARCHAR,
        Units LONG VARCHAR
     );
    
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-721*'
                        , 'A'
                        , '.'
                        ,'Database System Design and Implementation'
                        , 'Ailamaki'
                        , 'WeH 4615A'
                        , 'MWF'
                        , '1:30 - 2:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-744*'
                        , 'A'
                        , '.'
                        ,'Computer Networks'
                        , 'Zhang'
                        , 'WeH 5409'
                        , 'F'
                        , '1:30 - 4:20'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-750*'
                        , 'A'
                        , '.'
                        ,'Graduate        Algorithms'
                        , 'M. Blum'
                        , 'WeH 5409'
                        , 'MWF'
                        , '10:30 - 11:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-780*'
                        , 'A'
                        , '16-731'
                        ,'Advanced AI Concepts'
                        , 'Atkeson'
                        , 'NSH 1305'
                        , 'TR'
                        , '1:30 - 2:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-782'
                        , 'A'
                        , '15-496'
                        ,'Artificial        Neural Networks'
                        , 'Touretzky'
                        , 'TBA'
                        , 'MW'
                        , '3:30 - 4:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-785'
                        , 'A'
                        , '15-485/ 85-485/785'
                        ,'Computational        Perception and Scene Analysis'
                        , 'Lewicki'
                        , 'SH 422'
                        , 'TR'
                        , '3:00 - 4:20'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-802'
                        , 'A'
                        , '10-702'
                        ,'Statistical Approaches to Learning and Discovery'
                        , 'Lafferty, Wasserman, Seidenfeld'
                        , 'WeH 5409'
                        , 'MW'
                        , '12 - 1:20'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-812*'
                        , 'A'
                        , '.'
                        ,'Semantics of Programming Languages'
                        , 'Brookes'
                        , 'WeH 5409'
                        , 'TR'
                        , '10:30 - 11:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-815'
                        , 'A'
                        , '.'
                        ,'Automated Theorem        Proving'
                        , 'Pfenning'
                        , 'WeH 4601'
                        , 'TR'
                        , '10:30 - 11:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-818'
                        , 'A4'
                        , '.'
                        ,'Separation        Logic'
                        , 'Reynolds'
                        , 'WeH 4615A'
                        , 'TR'
                        , '3:00 - 4:20'
                        , '6'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-819'
                        , 'B'
                        , '.'
                        ,'Specification and Verification'
                        , 'Clarke / Reynolds'
                        , 'WeH 4615A'
                        , 'TR'
                        , '1:30 - 2:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-820'
                        , 'A'
                        , '.'
                        ,'Verification of Concurrent, Reactive,  Real-Time Prgrms'
                        , 'Clarke'
                        , 'WeH 4601'
                        , 'W'
                        , '3:30 - 4:50'
                        , '6'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-820'
                        , 'B'
                        , '.'
                        ,'Seminar in Software Systems: Queueing Theory and Scheduling'
                        , 'Harchol-Balter'
                        , 'WeH 8220'
                        , 'T'
                        , '12:00 - 1:50'
                        , '6'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-829'
                        , 'F'
                        , '18-732'
                        ,'Secure Software Systems'
                        , 'Song/Wing'
                        , 'MW               W'
                        , '12'
                        , NULL
                        , NULL
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-845'
                        , 'A'
                        , '.'
                        ,'Current Research Issues in Computer Systems'
                        , 'Steenkiste'
                        , 'WeH 7220'
                        , 'M'
                        , '12:00 - 1:20'
                        , '2'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-859'
                        , 'A'
                        , '.'
                        ,'Advanced Topics in Theory: Machine Learning Theory'
                        , 'A. Blum'
                        , 'WeH 5409'
                        , 'TR'
                        , '1:30 - 2:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-859'
                        , 'K'
                        , '21-801'
                        ,'Advanced Topics in Theory: Web Structure and Algorithms'
                        , 'A. Frieze'
                        , 'WeH 4615A'
                        , 'MW'
                        , '12:00 - 1:20'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-864'
                        , 'A'
                        , '.'
                        ,'Advanced        Computer Graphics'
                        , 'James'
                        , 'WeH 4615A'
                        , 'TR'
                        , '10:30 - 11:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-887*'
                        , 'A'
                        , '16-830'
                        ,'Planning, Execution and Learning'
                        , 'Veloso / Simmons'
                        , 'NSH 3002'
                        , 'MW'
                        , '1:30 - 2:50'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-889'
                        , 'D'
                        , '.'
                        ,'Building Speech        Recognition Systems'
                        , 'Baker / Reddy / Singh           TBA'
                        , 'TBA'
                        , 'WeH 5324'
                        , '12'
                        , NULL
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-899'
                        , 'B'
                        , '.'
                        ,'Computational Genomics: From Experimental Data to Systems Biology'
                        , 'Bar-Joseph'
                        , 'WeH 5409'
                        , 'TR'
                        , '9:00 - 10:20'
                        , '12'
        );
    
        INSERT INTO thalia.Demo.cmu (Code,Sec,CourseXListed,CourseTitle,Lecturer,Room,Day_,Time_,Units)
        VALUES ('15-998'
                        , 'A'
                        , '.'
                        ,'Computer Science Practicum Available to CSD PhD Students        Only'
                        , 'TBA'
                        , 'N/A'
                        , 'N/A'
                        , 'N/A'
                        , '1-36'
        );

    
DB.DBA.exec_no_error('DROP TABLE thalia.Demo.gatech');
    CREATE TABLE thalia.Demo.gatech (
        Department VARCHAR(2),
        Code INTEGER,
        Section VARCHAR(4),
        Mode_ VARCHAR(4),
        CRN VARCHAR(8) NOT NULL UNIQUE,
        Title LONG VARCHAR NOT NULL,
        Hours INTEGER,
        In_ INTEGER,
        Max_ INTEGER,
        Days VARCHAR(4),
        Time_ LONG VARCHAR,
        Instructor LONG VARCHAR,
        Room LONG VARCHAR,
        Building LONG VARCHAR,
        Description LONG VARCHAR
     );
    
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4001
                    , 'A'
                    , 'L'
                    ,'25727'
                    ,'Computing  Society'
                    , 3
                    , 40
                    , 42
                    , 'TR'
                    , '0305-0425pm'
                    , 'Rugaber'
                    , '320'
                    , 'Cherry Emerson'
                    , 'Course restricted: Only class JR SR.'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4001
                    , 'B'
                    , 'L'
                    ,'25728'
                    ,'Computing  Society'
                    , 3
                    , 41
                    , 42
                    , 'MWF'
                    , '0105-0155pm'
                    , 'Shaw'
                    , '101'
                    , 'Coll of Computing'
                    , 'Course restricted: Only class JR SR.'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4001
                    , 'D'
                    , 'L'
                    ,'25740'
                    ,'Computing  Society'
                    , 3
                    , 37
                    , 42
                    , 'TR'
                    , '0435-0555pm'
                    , 'Harrold'
                    , 'S204'
                    , 'Howey (Physics)'
                    , 'Course restricted: Only class JR SR.'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4001
                    , 'RNZ'
                    , 'LPA'
                    ,'25896'
                    ,'Computing  Society'
                    , 3
                    , 20
                    , 40
                    , 'TBA'
                    , 'TBA'
                    , 'Badre'
                    , 'TBA'
                    , ''
                    , 'Pacific Study Abroad in New Zealand'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4210
                    , 'A'
                    , 'LPA'
                    ,'21996'
                    ,'Adv Operating Systems'
                    , 3
                    , 37
                    , 42
                    , 'MWF'
                    , '0205-0255pm'
                    , 'Smaragdakis'
                    , '102'
                    , 'Coll of Computing'
                    , 'Enforced Pre-requisite(s): CS 2200 Or ECE 3055'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4220
                    , 'A'
                    , 'LPA'
                    ,'25778'
                    ,'Embedded Systems'
                    , 3
                    , 24
                    , 27
                    , 'TR'
                    , '1205-0125pm'
                    , 'Pu'
                    , '320'
                    , 'Cherry Emerson'
                    , 'TBA     TBA     Pu     TBA'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4235
                    , 'A'
                    , 'LPA'
                    ,'23615'
                    ,'Computer Networking II'
                    , 3
                    , 39
                    , 45
                    , 'TR'
                    , '0435-0555pm'
                    , 'Dovrolis'
                    , '101'
                    , 'Coll of Computing'
                    , 'Enforced Pre-requisite(s): CS 3251'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4255
                    , 'A'
                    , 'L'
                    ,'25779'
                    ,'Intro-Network Management'
                    , 3
                    , 37
                    , 40
                    , 'TR'
                    , '0935-1055am'
                    , 'Clark'
                    , '101'
                    , 'Coll of Computing'
                    , 'Enforced Pre-requisite(s): CS 3251'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4290
                    , 'A'
                    , 'LPA'
                    ,'20387'
                    ,'Advanced Computer Org'
                    , 3
                    , 4
                    , 10
                    , 'MWF'
                    , '0105-0155pm'
                    , 'Prvulovic'
                    , '102'
                    , 'Coll of Computing'
                    , 'Enforced Pre-requisite(s): CS 2200'
    );
    
    INSERT INTO thalia.Demo.gatech (Department,Code,Section,Mode_,CRN,Title,Hours,In_,Max_,Days,Time_,Instructor,Room,Building,Description)
    VALUES ('CS'
                    , 4330
                    , 'A'
                    , 'L'
                    ,'21831'
                    ,'Software Applications'
                    , 3
                    , 11
                    , 15
                    , 'TR'
                    , '0805-0925am'
                    , 'Rugaber'
                    , '102'
                    , 'Coll of Computing'
                    , 'TBA     TBA     Rugaber     TBA'
    );
    

DB.DBA.exec_no_error('DROP TABLE thalia.Demo.toronto');
    CREATE TABLE thalia.Demo.toronto (
        No_ VARCHAR(16) NOT NULL,
        level_ LONG VARCHAR,
        offeredTerm LONG VARCHAR,
        title LONG VARCHAR NOT NULL,
        instructorEmail LONG VARCHAR,
        instructorName LONG VARCHAR,
        location LONG VARCHAR,
        coursewebsite LONG VARCHAR,
        prereq LONG VARCHAR,
        text_ LONG VARCHAR
     );

                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2103/407'
                                , 'cross-listed'
                                , 'Fall 2003'
                                ,'Software Architecture and Design'
                                , 'Matthew Zaleski'
                                , 'matz@cdf.cs.toronto.edu'
                                , 'BA1170'
                                , 'http://www.cs.toronto.edu/~matz/instruct/csc407/'
                                , 'CSC340H (Information Systems Analysis and Design), CSC378H (Data Structures and Algorithm Analysis)'
                                , 'Design Patterns: Elements of Reusable Object-Oriented Software, Gamma et. al. Addison-Wesley (Professional Computing Series), 1995 ISBN 0-201-63361-2'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2104/465'
                                , 'cross-listed'
                                , 'Fall 2003'
                                ,'Formal Methods of Program Design'
                                , 'E.C.R. Hehner'
                                , 'hehner@cs.toronto.edu'
                                , 'BA5224'
                                , 'http://www.cs.toronto.edu/~hehner/csc465/'
                                , NULL
                                , 'E.C.R. Hehner, A Practical Theory of Programming, second edition, Springer, 2003'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2105/408'
                                , 'cross-listed'
                                , 'Fall 2003'
                                ,'Software Engineering'
                                , 'David Wortman'
                                , 'dw@cdf.toronto.edu'
                                , 'BA 1180'
                                , 'http://www.cdf.toronto.edu/~csc408h/fall/'
                                , 'CSC340, CSC378, or equivalent'
                                , 'Hans van Vliet, Software Engineering - Principles and Practice (2nd ed.), John Wiley, 2000.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2108'
                                , 'graduate'
                                , 'Fall 2003'
                                ,'Automated Verification'
                                , 'Marsha Chechik'
                                , 'chechik@cs.toronto.edu'
                                , 'Pratt 266'
                                , 'http://www.cs.toronto.edu/~chechik/courses03/csc2108/'
                                , 'Graduate standing or permission of instructor. Experience with model-checking and other formal methods, although helpful, is not necessary. However, the course assumes familiarity with basic computer science concepts: relations and functions; boolean and first-order logic (from undergrad discrete-math course), and finite-state machines. You are also expected to have basic knowledge of concurrency. The course includes a number of theoretical and engineering aspects.'
                                , '`Model Checking`, by Clarke, Grumberg, Peled, 1999, MIT Press.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2204/468'
                                , 'cross-listed'
                                , 'Fall 2003'
                                ,'Operating Systems'
                                , 'G. S. Graham'
                                , 'gsg@cs.toronto.edu'
                                , 'BA 1170'
                                , 'http://www.cs.toronto.edu/~gsg/468/'
                                , 'CSC258H1, CSC209H1/knowledge of concurrent programming'
                                , 'Applied Operating System Concepts (Windows XP Update), A. Silberschatz, P. B. GAlvin and G. Gagne, Wiley (2003).'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2209/458'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Computer Networks'
                                , 'P. Marbach'
                                , 'marbach@cs.toronto.edu'
                                , 'BA 1240'
                                , 'http://www.cs.toronto.edu/~marbach/csc458_F03.html'
                                , 'CSC258H, 354H/364H/372H/378H/ECE385H, STA250H/255H/257H/(80% in STA220H/ECO220Y)'
                                , 'Layered network architecture, ARQ retransmission strategies, delay models for data networks, multiaccess communication, routing, congestion control, addressing.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2221'
                                , 'graduate'
                                , 'Fall 2003'
                                ,'Topics in the Theory of Distributed Systems'
                                , 'Sam Toueg'
                                , 'sam@cs.toronto.edu'
                                , 'BA 1200'
                                , 'http://www.cs.toronto.edu/~vassos/teaching/2221/'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2221'
                                , 'graduate'
                                , 'Fall 2003'
                                ,'Topics in the Theory of Distributed Systems'
                                , 'Vassos Hadzilacos'
                                , 'vassos@cs.toronto.edu'
                                , 'BA 1200'
                                , 'http://www.cs.toronto.edu/~vassos/teaching/2221/'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2228'
                                , 'graduate'
                                , 'Fall 2003'
                                ,'Topics in Mobile and Pervasive Computing'
                                , 'Eyal De Lara'
                                , 'delara@cs.toronto.edu'
                                , 'BA 5256'
                                , 'http://www.cs.toronto.edu/~delara/courses/csc2228/'
                                , 'Basic understanding of operating system principles and knowledge of network programming'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2306/456'
                                , 'cross-listed'
                                , 'Fall 2003'
                                ,'High-Performance Scientific Computing'
                                , 'Christina C. Christara'
                                , 'ccc@cs.toronto.edu'
                                , 'LM 155'
                                , 'http://www.cs.toronto.edu/~ccc/Courses/cs456-2306.html'
                                , 'Elementary calculus: Taylor series, Rolle`s theorem, mean value theorem, graphs of functions, continuity, convergence, de l` Hospital`s rule, etc.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2307'
                                , 'graduate'
                                , 'Fall 2003'
                                ,'Numerical Software'
                                , 'Ken Jackson'
                                , 'krj@cs.toronto.edu'
                                , 'BA 2155'
                                , 'http://www.cs.toronto.edu/~krj/courses/2307/'
                                , 'Any previous numerical methods, numerical analysis, or scientific computing course.'
                                , 'The Engineering of Numerical Software, by Webb Miller, Prentice-Hall, 1984. Republished by the Custom Printing Dept., UofT Bookstore.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2401'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Introduction to Computational Complexity'
                                , 'Allan Borodin'
                                , 'bor@cs.toronto.edu'
                                , 'GB 412'
                                , 'http://www.cs.toronto.edu/~bor/2401f03/index.html'
                                , NULL
                                , 'Theory of Computational Complexity, Ding-Zhu Du and Ker-I KO'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2404/438'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Computability and Logic'
                                , 'S. Cook'
                                , 'sacook@cs.toronto.edu'
                                , 'BA 2156'
                                , 'http://www.cs.toronto.edu/~sacook/csc438h/'
                                , 'CSC 364/MAT247'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2405/448'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Automata Theory'
                                , 'Toniann Pitassi'
                                , 'toni@cs.toronto.edu'
                                , 'SS 1072'
                                , 'http://www.cs.toronto.edu/~toni/Courses/448-2003/CS448.html'
                                , 'Some knowledge of computability theory is recommended.'
                                , 'Introduction to the Theory of Computation, by Michael Sipser'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2414'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Expander graphs and their Applications'
                                , 'Shlomo Hoory'
                                , 'shlomoh@cs.toronto.edu'
                                , 'HA 316'
                                , 'http://www.cs.toronto.edu/~shlomoh/ExpandersF03.html'
                                , 'This course has no prerequisites.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2416'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Machine Learning Theory'
                                , 'Toniann Pitassi'
                                , 'toni@cs.toronto.edu'
                                , 'GB 220'
                                , 'http://www.cs.toronto.edu/~toni/Courses/MLTheory/ML.html'
                                , 'The only prerequisite for this course is the equivalent of CS364 (undergraduate  		complexity'
                                , 'An Introduction to Computational Learning Theory by Kearns and Vazirani.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2423'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Finite Model Theory and Descriptive Complexity'
                                , 'Leonid Libkin'
                                , 'libkin@cs.toronto.edu'
                                , 'BA 2135'
                                , 'http://www.cs.toronto.edu/~libkin/csc2423/f03/'
                                , 'being familiar with the basic notions of  		first-order propositional and predicate logic (if you  		took an undergrad logic.'
                                , 'L. Libkin, Elements of Finite Model Theory, 293pp, 1st draft'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2429'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Dynamic Data Structure'
                                , 'Faith Fich'
                                , 'fich@cs.toronto.edu'
                                , 'GB 412'
                                , 'http://www.cs.toronto.edu/~fich/DDS.html'
                                , 'A good undergraduate course in data structures (that focussed on correctness and complexity).'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2501/485'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Introduction to Computational Linguistics'
                                , 'Suzanne Stevenson'
                                , 'suzanne@cs.toronto.edu'
                                , 'SS 2129'
                                , 'http://www.cs.toronto.edu/~suzanne/2501/'
                                , 'a course in AI, knowledge of LISP, or Prolog; or a major in Linguistics; or permission of the instructor.'
                                , 'Jurafsky, Daniel, Martin, James H. Speech and Language Processing. Prentice-Hall, 2000.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2502/486'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Introduction to Knowledge Representation'
                                , 'Hector Levesque'
                                , 'hector@cs.toronto.edu'
                                , 'SS 2130'
                                , 'http://www.cs.toronto.edu/~hector/Courses/2502F03/'
                                , 'a course in AI and working knowledge of LISP and PROLOG'
                                , 'A hardcopy of the text for the course, a draft of a book by Brachman and Levesque, will be distributed in class.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2503/487'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Computational Vision I'
                                , 'Allan Jepson'
                                , 'jepson@cs.toronto.edu'
                                , 'UC 85'
                                , 'http://www.cs.toronto.edu/~jepson/csc2503/'
                                , 'MAT235 and CSC324, or equivalents'
                                , 'E. Trucco and A. Verri, Introductory Techniques for 3D Computer Vision, Prentice-Hall, 1998 (ISBN 0-13-261108-2).'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2504/418'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Computer Graphics'
                                , 'Tina Nicholl'
                                , 'tnicholl@cdf.toronto.edu'
                                , 'BA 1190'
                                , 'http://www.cdf.toronto.edu/~tnicholl/csc418/syllabus.htm'
                                , 'proficiency in C, and preferably C++.'
                                , 'F.S. Hill, Jr. Computer Graphics Using OpenGL, Second Edition, Prentice Hall, 2001.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2504/418'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Computer Graphics'
                                , 'Karan Singh'
                                , 'karan@dgp.toronto.edu'
                                , 'BA 1180'
                                , 'http://www.dgp.toronto.edu/~karan/courses/csc418/fall_2003/syllabus.html'
                                , 'proficiency in C, and preferably C++.'
                                , 'F.S. Hill, Jr. Computer Graphics Using OpenGL, Second Edition, Prentice Hall, 2001.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2514/428'
                                , 'cross-listed'
                                , 'Fall 2003/2004'
                                ,'Human-Computer Interaction'
                                , 'Ravin Balakrishnan'
                                , 'ravin@dgp.toronto.edu'
                                , 'BA 1210'
                                , 'http://www.dgp.toronto.edu/~ravin/courses/csc428f2003/'
                                , 'CSC318/324/372/378'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2515'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Machine Learning'
                                , 'Sam Roweis'
                                , 'roweis@cs.toronto.edu'
                                , 'HA 316'
                                , 'http://www.cs.toronto.edu/~roweis/csc2515/info.html'
                                , NULL
                                , 'Elements of Statistical Learning, Hastie, Tibsshirani, Friedman.'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2519'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Natural Language Semantics'
                                , 'Gerald Penn'
                                , 'gpenn@cs.toronto.edu'
                                , 'BA 2135'
                                , 'http://www.cs.toronto.edu/~gpenn/csc2519/'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2521'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Topics in Computer Graphics: Machine Learning'
                                , 'Aaron Hertzmann'
                                , 'hertzman@dgp.toronto.edu'
                                , 'SS 1080'
                                , 'http://www.dgp.toronto.edu/~hertzman/courses/csc2521/fall_2003/'
                                , 'CS grads or instructor permission'
                                , 'Information Theory, Inference, and Learning Algorithms, by David MacKay'
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2524'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Topic in Interactive Computing'
                                , 'Ravin Balakrishnan'
                                , 'ravin@dgp.toronto.edu'
                                , 'BA 2587'
                                , 'http://www.dgp.toronto.edu/~ravin/courses/csc2524f2003/'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2525'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Querying peer-to-peer databases'
                                , 'Renee Miller'
                                , 'miller@cs.toronto.edu'
                                , 'BA 5256'
                                , 'http://www.cs.toronto.edu/~miller/2525/'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2541'
                                , 'graduate'
                                , 'Fall 2003/2004'
                                ,'Topics in Machine Learning'
                                , 'Richard Zemel'
                                , 'zemel@cs.toronto.edu'
                                , 'BA 2135'
                                , 'http://www.cs.toronto.edu/~zemel/Courses/csc2541.html'
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2103/407'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Software Architecture And Design'
                                , 'Mathew Zaleski'
                                , 'matz@cdf.toronto.edu'
                                , 'BA 1170'
                                , NULL
                                , 'CSC340H (Information Systems Analysis and Design), CSC378H (Data Structures and Algorithm Analysis).'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2106'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Requirement Engineering'
                                , 'Steve Easterbrook'
                                , 'sme@cs.toronto.edu'
                                , 'UC 69'
                                , NULL
                                , 'CSC408 or permission of the instructor.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2105/408'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Software Engineering'
                                , 'David Wortman'
                                , 'dw@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'CSC340, CSC378, or equivalent'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2107/488'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Language Processors'
                                , 'David Wortman'
                                , 'dw@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'Courses in data structures and programming languages.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2206'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Computer System Modelling'
                                , 'Peter Marbach'
                                , 'marbach@cs.toronto.edu'
                                , 'KP 213'
                                , NULL
                                , 'Solid knowledge of basic probability theory.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2209/458'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Computer Networks'
                                , 'Peter Marbach'
                                , 'marbach@cs.toronto.edu'
                                , NULL
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2302'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Initial Value Methods For ODEs'
                                , 'Wayne Enright'
                                , 'enright@cs.toronto.edu'
                                , 'BA 2179'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2321'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Matrix Calculations'
                                , 'Christina Christara'
                                , 'ccc@cs.toronto.edu'
                                , 'BL 327'
                                , NULL
                                , 'calculus, numerical linear algebra, interpolation, some knowledge of PDEs, programming preferably in FORTRAN.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2410'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Algorithms in Graph Theory'
                                , 'Avner Magen'
                                , 'avner@cs.toronto.edu'
                                , 'WE 74'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2415'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Theoretical Aspects of Concurrent Programming'
                                , 'Sam Toueg'
                                , 'sam@cs.toronto.edu'
                                , 'WE 75'
                                , NULL
                                , 'This course will be concerned with various aspects of the theory underlying parallel architectures and concurrent programming. The following is a tentative list of topics: formalisms for expressing concurrency including flow expressions, path expressions, Petri nets; relative power of synchronization primitives; critical section solutions; the database consistency problem; language features for concurrent programming; e.g. monitors; proving the correctness of concurrent programs; mapping concurrent programs onto parallel architectures.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2415'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Theoretical Aspects of Concurrent Programming'
                                , 'Vassos Hadzilacos'
                                , 'vassos@cs.toronto.edu'
                                , 'WE 75'
                                , NULL
                                , 'This course will be concerned with various aspects of the theory underlying parallel architectures and concurrent programming. The following is a tentative list of topics: formalisms for expressing concurrency including flow expressions, path expressions, Petri nets; relative power of synchronization primitives; critical section solutions; the database consistency problem; language features for concurrent programming; e.g. monitors; proving the correctness of concurrent programs; mapping concurrent programs onto parallel architectures.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2426'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Topics in Cryptography'
                                , 'Charles Rackoff'
                                , 'rackoff@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'An introduction to cryptography including rigorous definitions of security, a presentation of the number theoretic background, and applications of number theory to various cryptographic problems.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2427'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Topics in Graph Theory'
                                , 'Michael Molloy'
                                , 'molloy@cs.toronto.edu'
                                , 'UC 257'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2506/412'
                                , 'cross'
                                , 'Winter 2003/2004'
                                ,'Probabilistic Reasoning'
                                , 'Sam Roweis'
                                , 'roweis@cs.toronto.edu'
                                , NULL
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2504/418'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Computer Graphics'
                                , 'Demetri Terzopoulos'
                                , 'dt@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'proficiency in C, and preferably C++.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2504/418'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Computer Graphics'
                                , 'Aaron Hertzmann'
                                , 'hertzman@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'proficiency in C, and preferably C++.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2510'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Conceptual Modeling'
                                , 'John Mylopoulos'
                                , 'jm@cs.toronto.edu'
                                , NULL
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2509'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Data Management Systems'
                                , 'Anthony Bonner'
                                , 'bonner@cs.toronto.edu'
                                , 'SS 1083'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2511/401'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'Natural Language Computing'
                                , 'Gerald Penn'
                                , 'gpenn@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'csc228, sta220/250/257 or equivalents'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2512'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Constraint Satisfaction Problems'
                                , 'Fahiem Bacchus'
                                , 'fbacchus@cs.toronto.edu'
                                , NULL
                                , NULL
                                , 'an introductory AI course (CSC384 or equivalent) or permission of the instructor'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2520'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'The Computational Lexicon'
                                , 'Suzanne Stevenson'
                                , 'suzanne@cs.toronto.edu'
                                , NULL
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2521'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Topics in Computer Graphics: Artificial Life'
                                , 'Demetri Terzopoulos'
                                , 'dt@cs.toronto.edu'
                                , 'MS 2290'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2523'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Computational Vision II'
                                , 'Sven Dickinson'
                                , 'sven@cs.toronto.edu'
                                , 'WB 258'
                                , NULL
                                , 'CSC484 or equivalent, and CSC2503'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2527/454'
                                , 'cross-listed'
                                , 'Winter 2003/2004'
                                ,'The Business of Software'
                                , 'TBA'
                                , NULL
                                , 'TBA'
                                , NULL
                                , 'CSC2204 (Operating Systems) or equivalent'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2528'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Topics in Computational Linguistics'
                                , 'Graeme Hirst'
                                , NULL
                                , 'UC 248'
                                , NULL
                                , 'CSC2501(485) or permission of instructor  Possible Preparatory Reading: Review the papers in recent issues of Computational Linguistics, and Proceedings of the annual conferences of the Association for Computational Linguistics.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2529'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Computer Animation'
                                , 'Karan Singh'
                                , 'karan@cs.toronto.edu'
                                , 'BA 2159'
                                , NULL
                                , NULL
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2530'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Visual Modeling'
                                , 'Kyros Kutulakos'
                                , 'kyros@cs.toronto.edu'
                                , 'BA 5287'
                                , NULL
                                , 'CSC2503, 2504, or permission of instructor.'
                                , NULL
                );
                
                INSERT INTO thalia.Demo.toronto (No_,level_,offeredTerm,title,instructorEmail,instructorName,location,coursewebsite,prereq,text_)
                VALUES ('CSC 2535'
                                , 'graduate'
                                , 'Winter 2003/2004'
                                ,'Computation in Neural Networks'
                                , 'Geoffrey Hinton'
                                , 'hinton@cs.toronto.edu'
                                , 'KP 113'
                                , NULL
                                , 'Some knowledge of calculus and linear algebra.'
                                , NULL
                );



DB.DBA.exec_no_error('DROP TABLE thalia.Demo.ucsd');
    CREATE TABLE thalia.Demo.ucsd (
        Number VARCHAR(32) NOT NULL,
        Title LONG VARCHAR NOT NULL,
        Fall2003 LONG VARCHAR,
        Winter2004 LONG VARCHAR,
        Spring2004 LONG VARCHAR
     );
    
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    200'
                    ,'Computability  Complexity'
                    , '-'
                    , 'Bellare'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    201A'
                    ,'Advanced Complexity'
                    , '-'
                    , '-'
                    , 'Impagliazzo'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    202'
                    ,'Algorithms and Analysis'
                    , 'Paturi (PhD)'
                    , 'Hu (MS)'
                    , 'Impagliazzo'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    203A'
                    ,'Advanced Algorithms'
                    , '-'
                    , 'Impagliazzo'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    204A'
                    ,'Combinatorial optimization'
                    , '-'
                    , '-'
                    , 'Hu'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    205A'
                    ,'Logic in Computer Science'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    206A'
                    ,'Lattice Algorithms and                    Applications'
                    , '-'
                    , 'Micciancio'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    206B'
                    ,'Algorithms in Computational                    Biology'
                    , '-'
                    , '-'
                    , 'Pevzner'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    207'
                    ,'Modern Cryptography'
                    , '-'
                    , '-'
                    , 'Bellare'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    208'
                    ,'Advanced Cryptography'
                    , '-'
                    , '-'
                    , 'Micciancio'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    209A'
                    ,'Top/Sem: Alg,Complexity                     Logic'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    209B'
                    ,'Top/Sem: Cryptography'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    210'
                    ,'Principles of Software                  Engineering'
                    , '-'
                    , '-'
                    , 'Griswold'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    211'
                    ,'Software Testing   Analysis'
                    , 'Cancelled'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    218'
                    ,'Adv Topics: Software                  Engineering'
                    , 'Griswold'
                    , 'Krueger'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    221'
                    ,'Operating Systems'
                    , 'Voelker (PhD)/ Savage (MS)'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    222A'
                    ,'Computer Communication  Networks'
                    , '-'
                    , 'Vahdat'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    222B'
                    ,'Internet Algorithmics'
                    , '-'
                    , '-'
                    , 'Canc'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    223A'
                    ,'Principles of Distributed                  Systems'
                    , '-'
                    , 'Marzullo'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    223B'
                    ,'Dist. Computing and Systems'
                    , '-'
                    , '-'
                    , 'Snoeren'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    224'
                    ,'Computer System Performance                    Evaluation'
                    , '-'
                    , 'Pasquale'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    225'
                    ,'High Perf Dist Comptg                   Grids'
                    , '-'
                    , '-'
                    , 'Chien'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    226'
                    ,'Storage Systems'
                    , '-'
                    , 'Burkhard'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    227'
                    ,'Computer Security'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    228'
                    ,'Multimedia Systems'
                    , '-'
                    , '-'
                    , 'Rangan'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    229A'
                    ,'Top/Sem: Computer Systems'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    229B'
                    ,'Top/Sem: Networks                     Communication'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    229C'
                    ,'Top/Sem: Computer Security'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    230'
                    ,'Principles Programming                  Languages'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    231'
                    ,'Advanced Compiler Design'
                    , 'Ferrante'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    232'
                    ,'Principles of Data Base  Systems'
                    , '-'
                    , 'Yannis'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    232B'
                    ,'Database System Implementation'
                    , '-'
                    , '-'
                    , 'Deutsch'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    233'
                    ,'Database Theory'
                    , '-'
                    , '-'
                    , 'Vianu'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    237A'
                    ,'Intro to Embedded Computing'
                    , '-'
                    , '-'
                    , 'Gupta'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    238'
                    ,'Topics Prog Lang Design                     Implem'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    240A'
                    ,'Principles of Computer                    Architecture'
                    , 'Calder'
                    , 'Orailoglu'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    240B'
                    ,'Advanced Computer Architecture'
                    , '-'
                    , '-'
                    , 'Calder'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    241A'
                    ,'Intro to Computing Circuitry'
                    , '-'
                    , 'See ECE 260B'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    242A'
                    ,'Integrated Circuit Layout                    Automation'
                    , '-'
                    , '-'
                    , 'Cheng'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    243A'
                    ,'Synthesis Methodologies in VLSI                    CAD'
                    , '-'
                    , 'Orailoglu'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    244A'
                    ,'VLSI Test'
                    , '-'
                    , 'Friedman'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    244B'
                    ,'Testable  Fault-Tolerant Hardware                    Des'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    245'
                    ,'Comp Aided Circuit Simulation                     Verif'
                    , '-'
                    , 'Cheng'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    246'
                    ,'Comp Arithmetic Algs  Hardware                    Des'
                    , '-'
                    , 'Cheng'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    247'
                    ,'Applic Specific  Reconfig Comp                    Arch'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    248'
                    ,'Alg  Optimization Found VLSI                    CAD'
                    , '-'
                    , '-'
                    , 'Kahng'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    249A'
                    ,'Top/Sem: Computer Architecture'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    249B'
                    ,'Top/Sem: VLSI'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    249C'
                    ,'Top/Sem: CAD'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    250A'
                    ,'Artificial Intelligence I'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    250B'
                    ,'Artificial Intelligence II'
                    , '_'
                    , '-'
                    , 'Dasgupta'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    252A'
                    ,'Computer Vision'
                    , '-'
                    , 'Kriegman'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    252B'
                    ,'Computer Vision II'
                    , '-'
                    , '-'
                    , 'Belongie'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    252C'
                    ,'Selected Topics in Vision                     Learning'
                    , 'Belongie'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    253'
                    ,'Neural Networks'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    254'
                    ,'Machine Learning'
                    , '-'
                    , '-'
                    , 'Elkan'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    255'
                    ,'Intelligent Systems'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    256'
                    ,'Statistical Natural Lang Proc'
                    , '-'
                    , '-'
                    , 'Cottrell'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    257'
                    ,'Computational Biology'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    257A'
                    ,'Biomolecular Seq  Structure                    Analy'
                    , '-'
                    , 'Pevzner'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    258A'
                    ,'Connectionists Natural  Language'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    259'
                    ,'Seminar Artificial Intellgnce'
                    , 'Cottrell'
                    , 'Cottrell'
                    , 'Cottrell'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    260'
                    ,'Parallel Computation'
                    , 'Baden'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    261'
                    ,'Parallel  Distributed                    Computation'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    262'
                    ,'Sys Supp Appl Par Computing'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    267'
                    ,'Computer Graphics, New'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    268A'
                    ,'Topics in Parallel Computing'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    268C'
                    ,'Topics High-Performance Prog'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    269'
                    ,'Seminar Parallel Computing'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    270'
                    ,'Statistics  Prob                    Manufacturing'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    271'
                    ,'User Intrface Des: Soc  Tech                    Issues'
                    , '-'
                    , '-'
                    , 'Goguen'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    272'
                    ,'Adv. Appearance Modeling'
                    , 'Jensen'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    275'
                    ,'Social Aspects Tech.                   Science'
                    , 'Goguen'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    268D'
                    ,'Social Aspects Tech  Sci'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    290'
                    ,'Seminar in CSE'
                    , '-'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    291'
                    ,'Topics in CSE'
                    , 'Bafna, Genomic Alg.'
                    , 'Elkan'
                    , 'Ludaescer, Process                Integration'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    292'
                    ,'Faculty Research Seminar'
                    , 'Bafna'
                    , 'Jensen'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    294'
                    ,'Research Mtg: Systems Seminar'
                    , 'Voelker'
                    , 'Snoeren'
                    , 'Staff'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    294'
                    ,'Research Mtg: Reliable Sys.                    Synthesis'
                    , 'Orailoglu'
                    , 'Orailoglu'
                    , 'Staff'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    294'
                    ,'Research Mtg: Database'
                    , 'Deutsch'
                    , '-'
                    , '-'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    294'
                    ,'Research Mtg: Meaning and                    Component'
                    , '-'
                    , '-'
                    , 'Goguen'
    );
    
    INSERT INTO thalia.Demo.ucsd (Number,Title,Fall2003,Winter2004,Spring2004)
    VALUES ('CSE                    599'
                    ,'Teaching Methods in CS'
                    , 'Kube and Dasgupta'
                    , '-'
                    , NULL
    );
    

DB.DBA.exec_no_error('DROP TABLE thalia.Demo.umd');
    CREATE TABLE thalia.Demo.umd (
        Code VARCHAR(8) NOT NULL,
        CourseName LONG VARCHAR NOT NULL,
        Credits LONG VARCHAR,
        GradeMethod LONG VARCHAR,
        SectionTitle LONG VARCHAR,
        SectionTime LONG VARCHAR
     );
    
    
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC102'
                                ,'Introduction to Information Technology;'
                                , '(3              credits)'
                                , 'REG/P-F/AUD.'
                                , '0101(13434)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  1115)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC102'
                                ,'Introduction to Information Technology;'
                                , '(3              credits)'
                                , 'REG/P-F/AUD.'
                                , '0201(13435)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  1115)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC102'
                                ,'Introduction to Information Technology;'
                                , '(3              credits)'
                                , 'REG/P-F/AUD.'
                                , '0301(13436)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  1115)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0101(13446) Emad, F. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  3117)                  MW........ 4:00pm- 4:50pm (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0102(13447) Emad, F. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  3117)                  MW........ 5:00pm- 5:50pm (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0201(13448) Maybury, J. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF....... 1:00pm- 1:50pm (CSI                  2117)                  MW........ 4:00pm- 4:50pm (CSI                  2118) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0203(13452) Maybury, J. (Seats=30, Open=2, Waitlist=0)'
                                , 'MWF....... 1:00pm- 1:50pm (CSI                  2117)                  MW........ 4:00pm- 4:50pm (CSI                  3120) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0101(13461) Bederson, B. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  1115)                  MW........12:00pm-12:50pm (CSI                  1121) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0102(13462) Bederson, B. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  1115)                  MW........ 1:00pm- 1:50pm (CSI                  1121) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0103(13463) Bederson, B. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  1115)                  MW........12:00pm-12:50pm (CSI                  2107) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0201(13464) Padua-Perez, N. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF....... 2:00pm- 2:50pm (CSI                  1115)                  MW........12:00pm-12:50pm (CSI                  2120) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0301(13465) Padua-Perez, N. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF....... 2:00pm- 2:50pm (CSI                  1115)                  MW........ 1:00pm- 1:50pm (CSI                  2120) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0401(13466) Padua-Perez, N. (FULL: Seats=25, Open=0,                  Waitlist=0)'
                                , 'MWF....... 2:00pm- 2:50pm (CSI                  1115)                  MW........ 1:00pm- 1:50pm (CSI                  2107) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0101(13477) Tjaden, B. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......10:00am-10:50am (CSI                  2117)                  MW........ 8:00am- 8:50am (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0102(13478) Tjaden, B. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......10:00am-10:50am (CSI                  2117)                  MW........ 9:00am- 9:50am (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0201(13479) Tjaden, B. (Seats=25, Open=6, Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  2117)                  MW........ 8:00am- 8:50am (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0202(13480) Tjaden, B. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......11:00am-11:50am (CSI                  2117)                  MW........ 9:00am- 9:50am (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0301(13481) Tjaden, B. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......12:00pm-12:50pm (CSI                  2117)                  MW........ 8:00am- 8:50am (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0302(13482) Tjaden, B. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF.......12:00pm-12:50pm (CSI                  2117)                  MW........ 9:00am- 9:50am (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0101(13492)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1115)                  MW........10:00am-10:50am (CSI                  1121) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0102(13493)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1115)                  MW........11:00am-11:50am (CSI                  1121) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0201(13494)'
                                , 'TuTh......11:00am-12:15pm (CSI                  1115)                  MW........10:00am-10:50am (CSI                  2107) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC114'
                                ,'Computer Science I;'
                                , '(4 credits)'
                                , 'REG/P-F/AUD.'
                                , '0202(13495)'
                                , 'TuTh......11:00am-12:15pm (CSI                  1115)                  MW........11:00am-11:50am (CSI                  2107) Dis'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC311'
                                ,'Computer              Organization;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13580) Arbaugh, W. (Seats=60, Open=14, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC311'
                                ,'Computer              Organization;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0201(13581) Arbaugh, W. (FULL: Seats=60, Open=0, Waitlist=0)'
                                , 'TuTh......11:00am-12:15pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13591) Herman, L. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MW........10:00am-10:50am (CSI                  3117)                  MW........ 2:00pm- 2:50pm (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0102(13592) Herman, L. (Seats=25, Open=8, Waitlist=0)'
                                , 'MW........10:00am-10:50am (CSI                  3117)                  MW........ 3:00pm- 3:50pm (CSI                  2107) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0201(13593) Herman, L. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MW........12:00pm-12:50pm (CSI                  1115)                  MW........ 2:00pm- 2:50pm (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0202(13594) Herman, L. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MW........12:00pm-12:50pm (CSI                  1115)                  MW........ 3:00pm- 3:50pm (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0301(13595) Herman, L. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MW........ 1:00pm- 1:50pm (CSI                  1115)                  MW........ 2:00pm- 2:50pm (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0302(13596) Herman, L. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MW........ 1:00pm- 1:50pm (CSI                  1115)                  MW........ 3:00pm- 3:50pm (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13606)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  1121)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0201(13607) Emad, F. (FULL: Seats=50, Open=0, Waitlist=0)'
                                , 'MWF....... 2:00pm- 2:50pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC330'
                                ,'Organization of              Programming Languages;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0301(13608) Emad, F. (FULL: Seats=60, Open=0, Waitlist=0)'
                                , 'MWF....... 3:00pm- 3:50pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC390'
                                ,'Honors Paper;'
                                , '(3              credits)'
                                , 'REG. Individual Instruction course:              contact department or instructor to obtain section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC411'
                                ,'Computer Systems Architecture;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(13679)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  1121)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC411'
                                ,'Computer Systems Architecture;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0201(13680)'
                                , 'MW........ 3:30pm- 4:45pm (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC412'
                                ,'Operating Systems;'
                                , '(4 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0101(13690)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  1122)                  MW........10:00am-10:50am (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC412'
                                ,'Operating Systems;'
                                , '(4 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0102(13691)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  1122)                  MW........11:00am-11:50am (CSI                  2120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC412'
                                ,'Operating Systems;'
                                , '(4 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0201(13692)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1121)                  MW........10:00am-10:50am (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC412'
                                ,'Operating Systems;'
                                , '(4 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0202(13693)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1121)                  MW........11:00am-11:50am (CSI                  3120) Lab'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC412'
                                ,'Operating Systems;'
                                , '(4 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0101(13703)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  2117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC420'
                                ,'Data Structures;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13713)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  2117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC420'
                                ,'Data Structures;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0201(13714)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  2117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC421'
                                ,'Introduction to Artificial              Intelligence;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13724)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC424'
                                ,'Database Design;'
                                , '(3 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0101(13734)'
                                , 'TuTh......11:00am-12:15pm (CSI                  1121)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC424'
                                ,'Database Design;'
                                , '(3 credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0201(13735) Shapiro, B. (Seats=50, Open=6, Waitlist=0)'
                                , 'Tu........ 6:30pm- 9:00pm (CSI                  2117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC426'
                                ,'Image Processing;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13744) Jacobs, D. (Seats=50, Open=15, Waitlist=0)'
                                , 'TuTh......11:00am-12:15pm (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC427'
                                ,'Computer Graphics;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13754)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC430'
                                ,'Theory of Language Translation;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(13764)'
                                , 'TuTh......11:00am-12:15pm (CSI                  2117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC433'
                                ,'Programming Language Technologies and              Paradigms;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13774)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC434'
                                ,'Introduction to Human-Computer              Interaction;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13784)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC434'
                                ,'Introduction to Human-Computer              Interaction;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0201(13785)'
                                , 'MW........ 2:00pm- 3:15pm (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC435'
                                ,'Software Engineering;'
                                , '(3              credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0101(13795)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  1121)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC435'
                                ,'Software Engineering;'
                                , '(3              credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0201(13796) Memon, A. (Seats=40, Open=2, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  2107)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC435'
                                ,'Software Engineering;'
                                , '(3              credits)'
                                , 'REG. CORE Capstone (CS) Course.'
                                , '0301(13797)'
                                , 'TuTh......11:00am-12:15pm (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC450'
                                ,'Logic for Computer Science;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(13806) Lopez-Escobar, E. (Seats=25, Open=3, Waitlist=0)'
                                , 'MWF....... 2:00pm- 2:50pm (MTH                  0405)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC451'
                                ,'Design and Analysis of Computer              Algorithms;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13816) Srinivasan, A. (Seats=50, Open=18, Waitlist=0)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  3117)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC456'
                                ,'Cryptology;'
                                , '(3 credits)'
                                , NULL
                                , '0101(13826)'
                                , 'MWF.......10:00am-10:50am (MTH                  B0421)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC456'
                                ,'Cryptology;'
                                , '(3 credits)'
                                , NULL
                                , '0201(13827) Washington, L. (FULL: Seats=45, Open=0,                  Waitlist=0)'
                                , 'MWF....... 1:00pm- 1:50pm (MTH                  B0421)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC460'
                                ,'Computational Methods;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(13837) Wolfe, P. (Seats=22, Open=3, Waitlist=0)'
                                , 'MWF....... 9:00am- 9:50am (MTH                  0304)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC460'
                                ,'Computational Methods;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0201(13838)'
                                , 'TuTh...... 2:00pm- 3:15pm (MTH                  0101)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC466'
                                ,'Introduction to Numerical Analysis I;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13848) Cooper, J. (FULL: Seats=25, Open=0, Waitlist=0)'
                                , 'MWF....... 1:00pm- 1:50pm (MTH                  0403)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC475'
                                ,'Combinatorics and Graph Theory;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(13858) Healy, D. (Seats=27, Open=7, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (MTH                  0306)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC498A'
                                ,'Special Problems in              Computer Science;'
                                , '(1-3 credits)'
                                , 'REG.              Individual Instruction course: contact department or instructor to              obtain section number.'
                                , '0101(14750)'
                                , 'Time and room to be arranged'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC498W'
                                ,'Special Problems in Computer Science:              Semantic Web;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(13929)'
                                , 'MW........ 2:00pm- 3:15pm (CSI                  1121)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC598'
                                ,'Practical Training;'
                                , '(1 credit)'
                                , 'S-F. Individual Instruction course:              contact department or instructor to obtain section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC661'
                                ,'Scientific Computing II;'
                                , '(3              credits)'
                                , 'REG.'
                                , '0101(14001)'
                                , 'TuTh......11:00am-12:15pm (CSI                  3118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC664'
                                ,'Advanced Scientific Computing II;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(14011)'
                                , 'TuTh...... 2:00pm- 3:15pm (MTH                  1308)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC666'
                                ,'Numerical Analysis I;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(14021) Osborn, J. (Seats=30, Open=19, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (MTH                  0303)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC667'
                                ,'Numerical Analysis II;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(14031) Liu, J. (Seats=25, Open=17, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (MTH                  0307)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC711'
                                ,'Computer Networks;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14041) Bhattacharjee, S. (FULL: Seats=20, Open=0,                  Waitlist=0)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC723'
                                ,'Natural Language Processing;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(14051)'
                                , 'W......... 4:00pm- 6:30pm (CSI                  3118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC724'
                                ,'Database Management Systems;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(14061)'
                                , 'TuTh......11:00am-12:15pm (CSI                  2118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC726'
                                ,'Machine Learning;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14071) Getoor, L. (Seats=40, Open=9, Waitlist=0)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC733'
                                ,'Computer Processing of Pictorial              Information;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14737) Aloimonos, J. (Seats=20, Open=4, Waitlist=0)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  3118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC740'
                                ,'Advanced Computer Graphics;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(14072) Varshney, A. (Seats=30, Open=2, Waitlist=0)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC751'
                                ,'Parallel Algorithms;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(59774)'
                                , 'MW........11:00am-12:15pm (CSI                  3118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC798'
                                ,'Graduate Seminar in              Computer Science;'
                                , '(1-3 credits)'
                                , 'REG/AUD.              Individual Instruction course: contact department or instructor to              obtain section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC799'
                                ,'Master`s Thesis              Research;'
                                , '(1-6 credits)'
                                , 'REG/S-F. Individual              Instruction course: contact department or instructor to obtain              section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC818S'
                                ,'Advanced Topics in Computer Systems: Grid              Computing;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14327) Sussman, A. (Seats=30, Open=18, Waitlist=0)'
                                , 'TuTh...... 2:00pm- 3:15pm (CSI                  2107)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC828A'
                                ,'Advanced Topics in              Information Processing;'
                                , '(1-3 credits)'
                                , 'REG/AUD. Individual Instruction course: contact department or              instructor to obtain section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC828C'
                                ,'Advanced Topics in Information              Processing: Human Factors in Computer and Information Systems;'
                                , '(3 credits)'
                                , 'REG.'
                                , '0101(59745)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  1122)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC828O'
                                ,'Advanced Topics in Information              Processing;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(59761)'
                                , 'M......... 5:30pm- 8:15pm (EGR                  3140)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC828R'
                                ,'Advanced Topics in Information              Processing: Medical Image Processing and Understanding;'
                                , '(3              credits)'
                                , 'REG/AUD.'
                                , '0101(59764) Chellappa, R. (Seats=30, Open=15, Waitlist=0)'
                                , 'MW........11:00am-12:15pm (CSI                  2118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC838A'
                                ,'Advanced Topics in              Programming Languages;'
                                , '(1-3 credits)'
                                , 'REG/AUD. Individual Instruction course: contact department or              instructor to obtain section number.'
                );
            
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC838G'
                                ,'Advanced Topics in Programming Languages:              New Devices for New Interactions;'
                                , '(3 credits)'
                                , NULL
                                , '0101(14469) Guimbretiere, F. (Seats=20, Open=15, Waitlist=0)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  2107)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC838I'
                                ,'Advanced Topics in Programming Languages:              HOW TO DO RESEARCH;'
                                , '(1 credit)'
                                , 'REG/AUD.'
                                , '0101(14479)'
                                , 'M......... 4:00pm- 4:50pm (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC838P'
                                ,'Advanced Topics in Programming Languages:              Software Engineering: Remote Analysis and Measurement of Software              Systems;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14489)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC838T'
                                ,'Advanced Topics in Programming Languages:              Systems Software for High Performance Computing, Emphasis on              Bioinformatic Applications;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14499)'
                                , 'TuTh......12:30pm- 1:45pm (CSI                  2107)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC838Z'
                                ,'Advanced Topics in Programming              Languages;'
                                , '(3 credits)'
                                , 'REG/AUD.'
                                , '0101(14509)'
                                , 'TuTh...... 3:30pm- 4:45pm (CSI                  2120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC858A'
                                ,'Advanced Topics in              Theory of Computing;'
                                , '(1-3 credits)'
                                , 'REG/AUD.              Individual Instruction course: contact department or instructor to              obtain section number.'
                                , '0101(14591)'
                                , 'MWF....... 1:00pm- 1:50pm (CSI                  2118)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod,SectionTitle,SectionTime)
                VALUES ('CMSC858K'
                                ,'Advanced Topics in Theory of Computing:              Advanced Topics in Cryptography;'
                                , '(3 credits)'
                                , NULL
                                , '0101(14601) Katz, J. (Seats=30, Open=9, Waitlist=0)'
                                , 'TuTh...... 9:30am-10:45am (CSI                  3120)'
                );
                
                INSERT INTO thalia.Demo.umd (Code,CourseName,Credits,GradeMethod)
                VALUES ('CMSC878A'
                                ,'Advanced Topics in              Numerical Methods;'
                                , '(1-3 credits)'
                                , 'REG/AUD.              Individual Instruction course: contact department or instructor to              obtain section number.'
                );
