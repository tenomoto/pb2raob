      INCLUDE   'readpb.prm'
C*
      CHARACTER outstg*(MXSTRL), subset*8
C*
      CHARACTER var ( MXR8VT )
     +    /'P','Q','T','Z','U','V'/
C*
      PARAMETER ( NFILO = 1 )
      INTEGER   iunso ( NFILO )
     +    /   52 /
      CHARACTER*6 filo ( NFILO )
     +    / 'ADPUPA'/
C*
      LOGICAL   found
C-----------------------------------------------------------------------
C
C*  Open the output files.
C
      DO ii = 1, NFILO
          OPEN  ( UNIT = iunso ( ii ),
     +            FILE = 'readpb.out.' // filo ( ii ) )
      END DO
C
C*  Open the input file.
C
      OPEN  ( UNIT = 11, FILE = 'prepbufr.in', FORM = 'UNFORMATTED' )
      CALL OPENBF  ( 11, 'IN', 11 )
      CALL DATELEN  ( 10 )
C
C*  Get the next station report from the input file.
C
  10  CALL READPB  ( 11, subset, idate, ierrpb )
      IF ( ierrpb .eq. -1 )  THEN
          STOP
      END IF
C
C*  Set the appropriate output file unit number.
C
      ii = 1
      found = .false.
      DO WHILE  ( ( .not. found ) .and. ( ii .le. NFILO ) )
          IF  ( subset (1:6) .eq. filo ( ii ) )  THEN
        found = .true.
        iuno = iunso ( ii )
          ELSE 
        ii = ii + 1
          END IF
      END DO
      IF  ( ( .not. found ) .and. ( ierrpb .eq. 0 ) )  THEN
          GO TO 10
      END IF
      if (ierrpb==0) then
C
C*  Skip if DHR/=0 
C
        if (hdr(4)/=0.0) then
          go to 10
        end if
C
C*  Skip if TYP /= 120 (p, Tv, q) and TYP /= 220 (u, v)
C
        if (.not.(hdr(6)==120.0.or.hdr(6)==220.0)) then
          go to 10
        end if
C
C*  Skip if T29 /= 11 (fixed land RAOB or PIBAL, but PIBAL is already excluded)
C*      and T20 /= 22 (ship RAOB)
C
        if (.not.(hdr(7)==11.0.or.hdr(7)==22.0)) then
          go to 10
        end if
      end if
C
C*  Print the HDR data for this station report.
C
#ifdef DEBUG
      WRITE  ( UNIT = iuno,
     +         FMT = '( /, A8, 1X, 2F7.2, 1X, F7.3, 1X, 2F8.1, '  //
     +               '1X, F7.1, 1X, F6.1 )' )
     +       ( hdr (ii), ii = 1, 8 )
#endif
C
C*  Print the EVNS data for this station report.
C
      DO lv = 1, nlev
#ifdef DEBUG
          WRITE  ( UNIT = iuno, FMT = '( 80("-") )' )
          WRITE  ( UNIT = iuno, FMT = '( "lev ", I4, 7A9 )' )
     +    lv, 'ob', 'qm', 'pc', 'rc', 'fc', 'an', 'cat'
          WRITE  ( UNIT = iuno, FMT = '( 80("-") )' )
#endif
#ifdef DEBUG
          DO kk = 1, MXR8VT
        DO jj = 1, MXR8VN
#else
          DO kk = 2, MXR8VT
        DO jj = 2, MXR8VN
#endif
C
C* Choose *QM (quality mark) <= 2.0 and *RC == 100 (original values)
C*        CAT = 1.0 or 3.0 (mandatory pressure levels)
C
         if ((evns(2, lv, jj, kk)<=2.0).and.
     +       (evns(4, lv, jj, kk)==100.0).and.
     +       ((evns(7, lv, 1, 1)==1.0).or.
     +        (evns(7, lv, 1, 1)==3.0))) then
#ifdef DEBUG
          WRITE  ( UNIT = outstg, FMT = '( A8, 7(1X,F8.1) )' )
     +      var (kk), ( evns ( ii, lv, jj, kk ), ii = 1, 7 )
#else
C better to leave units as it is 
C          if (var(kk)=="T") then ! degC => degK
C            evns(1, lv, jj, kk) = evns(1, lv, jj, kk) + 273.15d0
C          end if
C          if (var(kk)=="Q") then ! mg/kg => kg/kg
C            evns(1, lv, jj, kk) = evns(1, lv, jj, kk) * 1.0D-6
C          end if
          write(unit = outstg, fmt='(A5,2(F6.1),F6.0,A2,F8.1)')
     +      hdr(1), hdr(2), hdr(3), evns(1, lv, 1, 1), 
     +      var(kk), evns(1, lv, jj, kk)
#endif
          DO mm = 1, MXSTRL
            IF  ( outstg (mm:mm) .eq. '*' )  THEN
              outstg (mm:mm) = ' '
            END IF
          END DO
          IF  ( outstg (9:64) .ne. ' ' )  THEN
            WRITE  ( UNIT = iuno, FMT = '(A80)' )  outstg
          ENDIF
         end if
        END DO
          END DO
      END DO
C 
      IF  ( ierrpb .eq. 0 )  THEN
          GO TO 10
      END IF
C* 
      STOP
      END
C-----------------------------------------------------------------------
C-----------------------------------------------------------------------
      SUBROUTINE READPB  ( lunit, subset, idate, iret )
C
C*  This subroutine will read and combine the mass and wind subsets
C*  of the next station report in the prepbufr file.  It is styled
C*  after function IREADNS, and it only requires the prepbufr file
C*  to be opened for reading with OPENBF.  The combined station
C*  report is returned to the caller in COMMON /PREPBC/.
C*  This common area contains the number of levels in the report,
C*  a one dimensional array with the header information, and a four
C*  dimensional array containing all events from the variables POB,
C*  QOB, TOB, ZOB, UOB, and VOB for the report.
C*
C*  The header array contains the following list of mnemonics:
C*
C*  SID XOB YOB DHR ELV TYP T29 ITP
C*
C*  The 4-D array of data, EVNS ( ii, lv, jj, kk ), is indexed
C*  as follows:
C*
C*  "ii" indexes the event data types; these consist of:
C*          1) OBservation
C*          2) Quality Mark
C*          3) Program Code
C*          4) Reason Code
C*          5) ForeCast value
C*          6) ANalysed value
C*          7) office note CATegory
C*  "lv" indexes the levels of the report
C*  "jj" indexes the event stacks
C*  "kk" indexes the variable types (p,q,t,z,u,v)
C*
C*  Note that the structure of this array is identical to one
C*  returned from UFBEVN, with an additional (4th) dimension to
C*  include the six variable types into the same array.
C*
C*  The return codes are as follows:
C*  iret =  0 - normal return
C*       =  1 - the station report within COMMON /PREPBC/ contains the
C*        last available subset from within the prepbufr file
C*       = -1 - there are no more subsets available from within the
C*        prepbufr file 
C*
      INCLUDE   'readpb.prm'
C*
      CHARACTER*(*) subset
C* 
      CHARACTER*(MXSTRL)  head
     +    / 'SID XOB YOB DHR ELV TYP T29 ITP' /
C*
      CHARACTER*(MXSTRL)  ostr ( MXR8VT )
     +    / 'POB PQM PPC PRC PFC PAN CAT',
     +      'QOB QQM QPC QRC QFC QAN CAT',
     +      'TOB TQM TPC TRC TFC TAN CAT',
     +      'ZOB ZQM ZPC ZRC ZFC ZAN CAT',
     +      'UOB WQM WPC WRC UFC UAN CAT',
     +      'VOB WQM WPC WRC VFC VAN CAT'  /
C*
      REAL*8    hdr2 ( MXR8PM ),
     +      evns2 ( MXR8PM, MXR8LV, MXR8VN, MXR8VT )
C*
      REAL*8    r8sid, r8sid2, pob1, pob2
C*
      CHARACTER*8 csid, csid2, subst2
C*
      LOGICAL   match / .true. /
C*
      EQUIVALENCE ( r8sid, csid ), ( r8sid2, csid2 )
C*
      SAVE    match, subst2, idate2
C-----------------------------------------------------------------------
      iret = 0
C*
C*  If the previous call to this subroutine did not yield matching
C*  mass and wind subsets, then IREADNS is already pointing at an
C*  unmatched subset.  Otherwise, call IREADNS to advance the subset
C*  pointer to the next subset.
C*
      IF  ( match )  THEN
          IF  ( IREADNS  ( lunit, subset, idate ) .ne. 0 )  THEN
        iret = -1
        RETURN
          END IF
      ELSE
          subset = subst2
          idate = idate2
      END IF
C*
C*  Read the HDR and EVNS data for the subset that is currently
C*  being pointed to.
C*
      CALL UFBINT  ( lunit, hdr, MXR8PM, 1, jret, head )
      DO ii = 1, MXR8VT
          CALL UFBEVN  ( lunit, evns ( 1, 1, 1, ii ), MXR8PM, MXR8LV,
     +         MXR8VN, nlev, ostr (ii) )
      END DO
C
C*  Now, advance the subset pointer to the following subset and
C*  read its HDR data.
C
      IF  ( IREADNS  ( lunit, subset, idate ) .ne. 0 )  THEN
          iret = 1
          RETURN
      END IF
      CALL UFBINT  ( lunit, hdr2, MXR8PM, 1, jret, head )
C 
C*  Check whether these two subsets have identical SID, YOB, XOB,
C*  ELV, and DHR values.  If so, then they are matching mass and
C*  wind subsets for a single station report.
C
      match = .true.
C
      IF  ( subset .ne. subst2 )  THEN
          match = .false.
          RETURN
      END IF
C 
      r8sid = hdr (1)
      r8sid2 = hdr2 (1)
      IF  ( csid .ne. csid2 )  THEN
          match = .false.
          RETURN
      END IF
C 
      DO ii = 2, 5
          IF  ( hdr (ii) .ne. hdr2 (ii) )  THEN
        match = .false.
        RETURN
          END IF
      END DO
C
C*  Read the EVNS data for the second of the two matching subsets.
C 
      DO ii = 1, MXR8VT
          CALL UFBEVN  ( lunit, evns2 ( 1, 1, 1, ii ), MXR8PM, MXR8LV,
     +         MXR8VN, nlev2, ostr (ii) )
      ENDDO
C
C*  Combine the EVNS data for the two matching subsets into a
C*  single 4-D array.  Do this by merging the EVNS2 array into
C*  the EVNS array.
C
      DO 10 lv2 = 1, nlev2
          DO lv = 1, nlev
        pob1 = evns ( 1, lv, 1, 1 )
        pob2 = evns2 ( 1, lv2, 1, 1 )
        IF  ( pob1 .eq. pob2 )  THEN
C
C*      This pressure level from the second subset also exists
C*      in the first subset, so overwrite any "missing" piece
C*      of data for this pressure level in the first subset
C*      with the corresponding piece of data from the second
C*      subset (since this results in no net loss of data!).
C
          DO kk = 1, MXR8VT
            DO jj = 1, MXR8VN
              DO ii = 1, MXR8PM
          IF  ( evns ( ii, lv, jj, kk ) .eq. R8BFMS ) THEN
            evns ( ii, lv, jj, kk ) =
     +        evns2 ( ii, lv2, jj, kk )
          END IF
              END DO
            END DO
          END DO
          GO TO 10
        ELSE IF  (  ( pob2 .gt. pob1 )  .or.
     +           ( lv .eq. nlev )  )  THEN
C
C*      Either all remaining pressure levels within the first
C*      subset are less than this pressure level from the
C*      second subset (since levels within each subset are
C*      guaranteed to be in descending order wrt pressure!)
C*      *OR* there are more total levels within the second
C*      subset than in the first subset.  In either case, we
C*      should now add this second subset level to the end of
C*      the EVNS array.
C
          nlev = nlev + 1
          DO kk = 1, MXR8VT
            DO jj = 1, MXR8VN
              DO ii = 1, MXR8PM
          evns ( ii, nlev, jj, kk ) =
     +            evns2 ( ii, lv2, jj, kk )
              END DO
            END DO
          END DO
          GOTO 10
        END IF
          END DO
   10 END DO
C* 
      RETURN
      END

