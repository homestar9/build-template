/** Tests changelog section changes with both common line-ending styles. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "ChangelogService", function(){
			beforeEach( function(){
				changelogService = new build.lib.ChangelogService();
			} );

			it( "moves unreleased notes into a dated section", function(){
				var lf    = chr( 10 );
				var h2    = repeatString( chr( 35 ), 2 ) & " ";
				var h3    = repeatString( chr( 35 ), 3 ) & " ";
				var input = h2 & "[Unreleased]" & lf & lf
					& h3 & "Added" & lf & "- Clearer output" & lf & lf
					& h2 & "[1.0.0] - 2026-01-01" & lf & "- First release";
				var output = changelogService.moveUnreleasedNotes( input, "1.1.0", "2026-08-07" );

				expect( output ).toInclude( h2 & "[Unreleased]" & lf & lf & h2 & "[1.1.0] - 2026-08-07" );
				expect( output ).toInclude( h3 & "Added" & lf & "- Clearer output" );
				expect( output ).toInclude( h2 & "[1.0.0] - 2026-01-01" );
			} );

			it( "keeps Windows line endings", function(){
				var crlf  = chr( 13 ) & chr( 10 );
				var h2    = repeatString( chr( 35 ), 2 ) & " ";
				var input = h2 & "[Unreleased]" & crlf & crlf & "- Fixed" & crlf & crlf
					& h2 & "[1.0.0] - 2026-01-01" & crlf & "- First";
				var output = changelogService.moveUnreleasedNotes( input, "1.0.1", "2026-08-07" );

				expect( output ).toInclude( h2 & "[1.0.1] - 2026-08-07" & crlf );
				expect( replace( output, crlf, "", "all" ) ).notToInclude( chr( 10 ) );
			} );

			it( "rejects a missing unreleased section", function(){
				expect( function(){
					changelogService.moveUnreleasedNotes( "#chr( 35 )# Changelog", "1.0.1", "2026-08-07" );
				} ).toThrow( type = "BuildChangelog.MissingUnreleased" );
			} );

			it( "rejects an empty unreleased section", function(){
				var lf = chr( 10 );
				var h2 = repeatString( chr( 35 ), 2 ) & " ";
				expect( function(){
					changelogService.moveUnreleasedNotes(
						h2 & "[Unreleased]" & lf & lf & h2 & "[1.0.0] - 2026-01-01" & lf & "- First",
						"1.0.1",
						"2026-08-07"
					);
				} ).toThrow( type = "BuildChangelog.EmptyUnreleased" );
			} );

			it( "extracts one version without matching a longer prerelease version", function(){
				var lf    = chr( 10 );
				var h2    = repeatString( chr( 35 ), 2 ) & " ";
				var input = h2 & "[1.2.0-beta.1] - 2026-08-01" & lf & "Beta notes" & lf & lf
					& h2 & "[1.2.0] - 2026-08-07" & lf & "Final notes";
				expect( changelogService.extractReleaseNotes( input, "1.2.0" ) ).toBe( "Final notes" );
			} );

			it( "rejects missing and empty version sections", function(){
				var lf = chr( 10 );
				var h2 = repeatString( chr( 35 ), 2 ) & " ";
				expect( function(){
					changelogService.extractReleaseNotes( h2 & "[1.0.0]" & lf & "Notes", "2.0.0" );
				} ).toThrow( type = "BuildChangelog.MissingVersion" );

				expect( function(){
					changelogService.extractReleaseNotes(
						h2 & "[1.0.0]" & lf & lf & h2 & "[0.9.0]" & lf & "Old",
						"1.0.0"
					);
				} ).toThrow( type = "BuildChangelog.EmptyVersion" );
			} );
		} );
	}
}
