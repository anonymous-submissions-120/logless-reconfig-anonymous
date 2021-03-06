---- MODULE MongoLoglessDynamicRaftAux ----
EXTENDS TLC, MongoLoglessDynamicRaft

\*
\* Extended version of MongoLoglessDynamicRaft that includes history variables
\* for checking correctness properties and for defining refinement mapping between
\* between the "logless" protocol and a log-based versions of the protocol.
\*

\* Auxiliary history variables.
VARIABLE log
VARIABLE committedConfigs

InitAux == 
    /\ Init
    /\ log = [s \in Server |-> <<>>] 
    /\ committedConfigs = {}

ReconfigAux == 
    \E s \in Server, newConfig \in SUBSET Server : 
        /\ Reconfig(s, newConfig) 
        /\ log' = [log EXCEPT ![s] = Append(log[s], currentTerm[s])]
        /\ UNCHANGED <<committedConfigs>>

SendConfigAux == 
    \E s,t \in Server : 
        /\ SendConfig(s, t)
        /\ log' = [log EXCEPT ![t] = log[s]]
        /\ UNCHANGED <<committedConfigs>>

BecomeLeaderAux == 
    \E i \in Server : \E Q \in Quorums(config[i]) :  
        /\ BecomeLeader(i, Q)
        /\ log' = [log EXCEPT ![i] = Append(log[i], currentTerm[i] + 1)]
        /\ UNCHANGED <<committedConfigs>>  

CommitConfigAux == 
    \E s \in Server :
        /\ ConfigIsCommitted(s)
        /\ committedConfigs' = committedConfigs \cup 
            {[ entry  |-> <<Len(log[s]), configTerm[s]>>,
                term  |-> currentTerm[s],
                configVersion |-> configVersion[s],
                configTerm |-> configTerm[s]]}
        /\ UNCHANGED <<currentTerm, log, state, config, configVersion, configTerm>>

\* Next state relation with auxiliary variables.
NextAux ==
    \/ ReconfigAux
    \/ SendConfigAux
    \/ BecomeLeaderAux
    \* Record commits explicitly to simulate the behavior of MongoSafeWeakRaft.
    \/ CommitConfigAux

\* If two entries are committed at the same index, they must be the same entry.
ConfigStateMachineSafety == 
    \A c1, c2 \in committedConfigs : (c1.entry[1] = c2.entry[1]) => (c1 = c2)

\* If a configuration C is committed in term T, then every primary in a higher term 
\* contains C or a newer config.
CommittedConfigSafety == 
    \A s \in Server :
    \A c \in committedConfigs : 
        (state[s]=Primary /\ currentTerm[s] > c.configTerm) => 
        NewerOrEqualConfig(<<configVersion[s], configTerm[s]>>, <<c.configVersion, c.configTerm>>)

====