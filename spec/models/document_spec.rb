# encoding: UTF-8
require 'spec_helper'

describe 'Document' do

  it "should not find a date" do

    document = Factory(:document)

    puts document.find_likely_dates
    document.find_likely_dates.should == nil
  end

  it "should return nil given a far future date" do

    document = Factory(:document)
    document.content_url = "http://www.barrecity.org/vertical/sites/%7BC56D92D5-E575-4F98-981D-17D0AE52466F%7D/uploads/%7B063C0738-B93D-4CBC-882A-25170C87B3C5%7D.PDF"
    document.extracted_text = "To be approved at 12-08-09 Barre City Council
                              Meeting Regular Meeting of the Barre City Council
                              Held December 1, 2444"

    document.find_likely_dates.should == nil
  end

  it "should find a date of Decmeber 1, 2009" do

    document = Factory(:document)
    document.content_url = "http://www.barrecity.org/vertical/sites/%7BC56D92D5-E575-4F98-981D-17D0AE52466F%7D/uploads/%7B063C0738-B93D-4CBC-882A-25170C87B3C5%7D.PDF"
    document.extracted_text = "To be approved at 12-08-09 Barre City Council
                              Meeting Regular Meeting of the Barre City Council
                              Held December 1, 2009"

    document.find_likely_dates.should == Date.parse("December 1, 2009")
  end

  it "should find a date of June 8, 2012" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "To be approved at 12-08-09 Barre City Council Meeting
                              Regular Meeting of the Barre City Council
                              Held June 8th, 2012"

    document.find_likely_dates.should == Date.parse("June 8, 2012")
  end

  it "should find a date of September 12, 1975" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "To be approved at 12-08-09 Barre City Council Meeting
                              Regular Meeting of the Barre City Council
                              Held Sept. 12th, 1975"

    document.find_likely_dates.should == Date.parse("September 12, 1975")
  end

  it "should find a date of November 29, 2011" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "To be approved at 12-06-11 Barre City Council Meeting
                              Regular Meeting of the Barre City Council
                              Held November 29, 2011

                              The Regular Meeting of the Barre City Council was called to order at 7:00 PM by Mayor Thomas
                              Lauzon. In attendance were: From Ward I, Councilor Paul Poirier ("

    document.find_likely_dates.should == Date.parse("November 29, 2011")
  end

  it "should find a date of November 30, 2010" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "To be approved at 12-07-10 Barre City Council Meeting
Regular Meeting of the Barre City Council
Held November 30, 2010

The Regular Meeting of the Barre City Council was called to order at 7:00 PM by Mayor
Thomas Lauzon. In attendance were: From Ward I, Councilors Etli and Poir"

    document.find_likely_dates.should == Date.parse("November 30, 2010")
  end

  it "should find a date of May 25th, 2012" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "CITY OF MONTPELIER
CAPITAL CITY OF VERMONT

City Managerâs Weekly Report â 5/25/12

UPCOMING MEETINGS â¦

Memorial Day Observed: City Hall Offices will be closed on Monday,
th
May 28; the parade will start at the roundabout at 10:00 A.M. (assembly at
9:30). …
"

    document.find_likely_dates.should == Date.parse("May 25th, 2012")
  end

  it "should find a date of June 10th, 2008" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "MINUTES SUBJECT TO CORRECTION BY THE ESSEX JUNCTION BOARD OF TRUSTEES. CHANGES, IF \nANY, WILL BE RECORDED IN THE MINUTES OF THE NEXT MEETING OF THE BOARD. \nVILLAGE OF ESSEX JUNCTION \nBOARD OF TRUSTEES \nMINUTES OF MEETING June 10, 2008 \n \nBOARD OF TRUSTEES: Larry Yandow (Village President); Deb Billa
"

    document.find_likely_dates.should == Date.parse("June 10th, 2008")
  end

  it "should find a date of June 24th, 2006" do

    document = Factory(:document)
    document.content_url = "http://www.url.gov/2009-09-12"
    document.extracted_text = "Minutes of Bolton School Directors Meeting
Sleepy Hollow Inn, Huntington, VT
June 24 , 2006
"

    document.find_likely_dates.should == Date.parse("June 24, 2006")
  end
end