class String

  STOPWORDS = "a,able,about,across,adobe,after,all,almost,also,am,among,an,and,any,apr,april,are,as,at,aug,august,be,because,been,before,below,but,by,can,cannot,civicplus,com,could,date,dear,dec,december,did,do,does,each,eight,either,else,ever,every,feb,february,five,for,four,from,get,got,govoffice,had,has,have,he,her,here,hers,him,his,how,however,i,if,in,inc,into,is,it,its,jan,january,jul,july,jun,june,just,know,least,let,like,likely,main,many,mar,march,massachusetts,may,may,may,me,might,most,motion,mrs,much,must,my,neither,nine,no,nor,not,nov,november,oct,october,of,off,often,on,one,only,or,other,our,own,per,please,rather,said,say,says,sep,sept,september,set,seven,shall,she,should,since,sitemap,six,so,some,such,ten,than,that,the,their,them,then,there,these,they,this,three,time,tis,to,too,translate,twas,two,us,use,used,very,wants,was,we,webmaster,website,were,what,when,where,which,while,who,whom,why,will,with,would,www,yet,you,your".split(",")

  def ellipsisize(minimum_length=4,edge_length=3)
    return self if self.length < minimum_length or self.length <= edge_length*2
    edge = '.'*edge_length
    mid_length = self.length - edge_length*2
    gsub(/(#{edge}).{#{mid_length},}(#{edge})/, '\1...\2')
  end

  def clean_for_topic_analysis
    ret = self.gsub(/From\s*:.+?Subject\s*:/m, "")
    ret = ret.gsub('"', " ").gsub("'", " ").gsub(",", "")
    ret = ret.gsub(/[^A-Za-z]/, " ")
    ret = ret.remove_stopwords
    ret = ret.collapse_whitespace
    ret
  end

  def remove_stopwords
    ret = self
    STOPWORDS.each do |stopword|
      ret = ret.gsub(/^#{stopword}\s/i, " ")
      ret = ret.gsub(/\s#{stopword}$/i, " ")
      ret = ret.gsub(/\s#{stopword}\s/i, " ")
    end
    ret
  end

  def collapse_whitespace
    self.gsub(/\s+/, " ").squeeze(' ').strip
  end

  def remove_nonalphanumeric
    self.gsub(/[^a-zA-Z0-9]/, "")
  end

  def extract_first_email
    x = self.fix_encoding
    first_email_regex = /(From\s*:.*?)From\s*:/m
    if x =~ first_email_regex
      return x.match(first_email_regex).captures.first
    else
      return x
    end
  end
end