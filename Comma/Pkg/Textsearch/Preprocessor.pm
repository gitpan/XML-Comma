##
#
#    Copyright 2001 AllAfrica Global Media
#
#    This file is part of XML::Comma
#
#    XML::Comma is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    For more information about XML::Comma, point a web browser at
#    http://xymbollab.com/tools/comma/, or read the tutorial included
#    with the XML::Comma distribution at docs/guide.html
#
##

package XML::Comma::Pkg::Textsearch::Preprocessor;

use Lingua::Stem;

use strict;

use XML::Comma::Util qw( dbg );

my %Preprocessor_Stopwords;

# usage: @list_of_words = XML::Comma::Pkg::Textsearch::Preprocessor->stem($text)
sub stem {
  my %dups;
  return grep { ! defined $Preprocessor_Stopwords{$_} }
    grep { $_ and (! $dups{$_} ++) and (length($_) <= 12) }
      @{Lingua::Stem::stem ( split(m:[\s\W]+:, $_[1]) )};
}

BEGIN {
  %Preprocessor_Stopwords = map { $_ => 1 }
    qw(
          a
          about
          abov
          abst
          accord
          accordingli
          across
          act
          actual
          ad
          adj
          adopt
          affect
          after
          afterward
          again
          against
          all
          almost
          alon
          along
          alreadi
          also
          although
          alwai
          am
          among
          amongst
          an
          and
          announc
          anoth
          ani
          anyhow
          anyon
          anyth
          anywher
          appar
          ar
          aren
          arent
          aris
          around
          a
          asid
          at
          auth
          avail
          awai
          b
          be
          becam
          becaus
          becom
          been
          befor
          beforehand
          begin
          behind
          be
          below
          besid
          between
          beyond
          billion
          biol
          both
          briefli
          but
          by
          c
          ca
          came
          can
          cannot
          cant
          caption
          certain
          certainli
          chem
          co
          contain
          copyright
          could
          couldn
          couldnt
          d
          date
          did
          didn
          didnt
          differ
          do
          doe
          doesn
          doesnt
          don
          done
          dont
          down
          due
          dure
          e
          each
          ed
          effect
          eg
          eight
          eighti
          either
          els
          elsewher
          end
          enough
          especi
          et-al
          etc
          even
          ever
          everi
          everyon
          everyth
          everywher
          except
          f
          far
          few
          fifti
          first
          five
          fix
          follow
          for
          former
          formerli
          forti
          found
          four
          from
          further
          g
          gave
          get
          gif
          give
          given
          give
          go
          gone
          got
          h
          had
          hardli
          ha
          hasn
          hasnt
          have
          haven
          havent
          have
          he
          hed
          hell
          henc
          her
          here
          hereaft
          herebi
          herein
          here
          hereupon
          her
          herself
          he
          hid
          him
          himself
          hi
          home
          hop
          how
          howev
          href
          html
          hundr
          i
          id
          ie
          if
          ill
          im
          immedi
          import
          in
          inc
          includ
          inde
          index
          inform
          instead
          internet
          into
          i
          isn
          isnt
          it
          itself
          iv
          j
          jpg
          jpeg
          just
          k
          keep
          kept
          kei
          kg
          km
          knowledg
          l
          larg
          last
          later
          latter
          latterli
          least
          less
          let
          like
          line
          link
          ll
          ltd
          m
          made
          mainli
          make
          mani
          mai
          mayb
          me
          meantim
          meanwhil
          mg
          might
          million
          miss
          ml
          more
          moreov
          most
          mostli
          mr
          much
          mug
          must
          my
          myself
          n
          na
          name
          near
          nearli
          necessarili
          neither
          never
          nevertheless
          new
          next
          nine
          nineti
          no
          nobodi
          none
          nonetheless
          noon
          nor
          normal
          no
          not
          note
          noth
          now
          nowher
          o
          obtain
          of
          off
          often
          oh
          omit
          on
          onc
          on
          onli
          onto
          or
          ord
          other
          otherw
          ought
          our
          ourselv
          out
          over
          overal
          ow
          own
          p
          page
          part
          particularli
          past
          per
          perhap
          pleas
          poorli
          possibl
          potenti
          pp
          predominantli
          present
          previous
          primarili
          probabl
          prompt
          promptli
          proud
          put
          q
          quickli
          quit
          r
          ran
          rather
          re
          readili
          realli
          recent
          ref
          regardless
          relat
          rel
          research
          respect
          result
          run
          s
          said
          same
          sai
          search
          sec
          section
          seem
          seen
          server
          seven
          seventi
          sever
          she
          she
          shed
          shell
          she
          should
          shouldn
          shouldnt
          show
          shown
          show
          significantli
          similar
          similarli
          sinc
          six
          sixti
          slightli
          so
          some
          somehow
          someon
          somethan
          someth
          sometim
          somewhat
          somewher
          soon
          specif
          state
          still
          stop
          strongli
          substanti
          successfulli
          such
          suffici
          t
          take
          ten
          than
          that
          thatl
          that
          thatv
          the
          their
          them
          themselv
          then
          thenc
          there
          thereaft
          therebi
          there
          therefor
          therein
          therel
          therer
          there
          thereupon
          therev
          these
          thei
          theyd
          theyl
          theyr
          theyv
          thirti
          thi
          those
          though
          thoughh
          thousand
          three
          throug
          through
          throughout
          thru
          thu
          til
          tip
          to
          togeth
          too
          toward
          trillion
          try
          twenti
          two
          u
          under
          unless
          unlik
          until
          unto
          up
          upon
          up
          u
          us
          usefulli
          us
          usual
          v
          variou
          ve
          veri
          via
          vol
          v
          w
          wa
          wasn
          wasnt
          wai
          we
          web
          wed
          well
          were
          weren
          werent
          weve
          what
          whatev
          whatl
          what
          whatv
          when
          whenc
          whenev
          where
          whereaft
          wherea
          wherebi
          wherein
          where
          whereupon
          wherev
          whether
          which
          while
          whim
          whither
          who
          whod
          whoever
          whole
          wholl
          whom
          whomev
          who
          whose
          why
          wide
          will
          with
          within
          without
          won
          wont
          word
          world
          would
          wouldn
          wouldnt
          www
          x
          y
          ye
          yet
          you
          youd
          youll
          your
          yourself
          yourselv
          youv
          z );
}

1;

