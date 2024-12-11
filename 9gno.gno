package memecoin

import (
    "std"
    "strings"
    "time"
    "strconv"
    
    "gno.land/p/demo/grc/grc20"
    "gno.land/p/demo/memeland"
    "gno.land/p/demo/ufmt"
    "gno.land/p/moul/md"
)

var (
    Token, ledger = grc20.NewToken("9GNO", "9GNO", 6)
    memes = memeland.NewMemeland()
    captains = make(map[std.Address]bool)

    memeDatas string
)

func init() {
    if err := ledger.Mint("g1ej0qca5ptsw9kfr64ey8jvfy9eacga6mpj2z0y", 90_000_000 * 1_000_000); err != nil {
        panic(err.Error())
    }
    memes.TransferOwnership("g1ej0qca5ptsw9kfr64ey8jvfy9eacga6mpj2z0y")
}

func PostMeme(content string, imageURL string) string {
    caller := std.GetOrigCaller()
    
    if imageURL != "" && !isValidImageURL(imageURL) {
        panic("invalid image URL - must end with .jpg, .jpeg, .png, .gif, or .webp")
    }
    
    if Token.BalanceOf(caller) < 999 * 1_000_000 {
        panic("insufficient 9GNO balance to post memes")
    }
    
    memeData := ""
    if imageURL != "" {
        memeData = `{"content":"` + content + `","image":"` + imageURL + `"}`
    } else {
        memeData = `{"content":"` + content + `"}`
    }
    
    memeDatas += memeData
    return memes.PostMeme(memeData, time.Now().Unix())
}

func LikeMeme(memeID string) {
    caller := std.GetOrigCaller()
    
    memes.Upvote(memeID)
    
    posts := memes.GetPostsInRange(0, time.Now().Unix(), 1, 1, "DATE_CREATED")
    if posts == "[]" {
        panic("meme not found")
    }
    
    // meme creator gets 9 tokens for each like
    if err := ledger.Mint(caller, 9 * 1_000_000); err != nil {
        panic(err.Error())
    }
    
    updateCaptainStatus(caller)
}

func GetMemes(page, pageSize int, sortBy string) string {
    return memes.GetPostsInRange(0, time.Now().Unix(), page, pageSize, sortBy)
}

func isValidImageURL(url string) bool {
    validExtensions := []string{".jpg", ".jpeg", ".png", ".gif", ".webp"}
    for _, ext := range validExtensions {
        if strings.HasSuffix(strings.ToLower(url), ext) {
            return true
        }
    }
    return false
}

func updateCaptainStatus(addr std.Address) {
    balance := Token.BalanceOf(addr)
    if balance >= 99_999 * 1_000_000 { // ~100k tokens 
        captains[addr] = true
    } else {
        delete(captains, addr)
    }
}

func IsCaptain(addr std.Address) bool {
    return captains[addr]
}

func Render(path string) string {


    posts := memes.GetPostsInRange(0, time.Now().Unix(), 1, 9, "DATE_CREATED")
    if posts == "[]" {
        return md.H2("No memes posted yet!") + 
               md.Paragraph("Be the first to post a meme!")
    }
    
    var sb strings.Builder

    balance := Token.BalanceOf("g1dxr7hh6rm3r5wlrkg23qm0fugak3lu8x30kky8")
    sb.WriteString("Balance: ")
    sb.WriteString(ufmt.Sprintf("%d 9GNO", balance/1_000_000))
    sb.WriteString("\n")
    sb.WriteString(md.H1("9GNO Meme Feed"))
    sb.WriteString(md.HorizontalRule())
    
    // remove [] from the posts string and split by },{
    posts = strings.TrimPrefix(posts, "[")
    posts = strings.TrimSuffix(posts, "]")
    memeList := strings.Split(posts, "},{")
    
    for i, memeJSON := range memeList {
        // clean up the JSON string
        if i > 0 {
            memeJSON = "{" + memeJSON
        }
        if i < len(memeList)-1 {
            memeJSON = memeJSON + "}"
        }
        
        // extract content and image URL
        content := extractJSONValue(memeJSON, "content")
        imageURL := extractJSONValue(memeJSON, "image")

        // build meme card
        sb.WriteString(md.H3("Meme #" + strconv.Itoa(i+1)))
        sb.WriteString("\n")
        if imageURL != "" {
            sb.WriteString(md.Image("meme", imageURL))
            sb.WriteString("\n\n")
        }
        sb.WriteString(md.Blockquote(content))
        sb.WriteString(md.HorizontalRule())
    }
    
    return sb.String()
}

func extractJSONValue(jsonStr, key string) string {
    if key == "content" || key == "image" {
        dataStr := extractDataField(jsonStr)
        if dataStr == "" {
            return ""
        }
        jsonStr = dataStr
    }
    
    keyStr := `"` + key + `":`
    idx := strings.Index(jsonStr, keyStr)
    if idx == -1 {
        return ""
    }
    
    start := idx + len(keyStr)
    jsonStr = strings.TrimSpace(jsonStr[start:])
    
    if strings.HasPrefix(jsonStr, `"`) {
        jsonStr = jsonStr[1:]
        end := 0
        for i := 0; i < len(jsonStr); i++ {
            if jsonStr[i] == '"' && (i == 0 || jsonStr[i-1] != '\\') {
                end = i
                break
            }
        }
        if end == 0 {
            return ""
        }
        return strings.ReplaceAll(jsonStr[:end], `\"`, `"`)
    }
    
    end := strings.IndexAny(jsonStr, ",}")
    if end == -1 {
        return jsonStr
    }
    return strings.TrimSpace(jsonStr[:end])
}


func extractDataField(jsonStr string) string {
    dataKey := `"data":`
    idx := strings.Index(jsonStr, dataKey)
    if idx == -1 {
        return ""
    }
    
    jsonStr = strings.TrimSpace(jsonStr[idx+len(dataKey):])
    
    if strings.HasPrefix(jsonStr, `"`) {
        jsonStr = jsonStr[1:]
        end := 0
        for i := 0; i < len(jsonStr); i++ {
            if jsonStr[i] == '"' && (i == 0 || jsonStr[i-1] != '\\') {
                end = i
                break
            }
        }
        if end == 0 {
            return ""
        }
        return strings.ReplaceAll(jsonStr[:end], `\"`, `"`)
    }
    return ""
}

