package main

import (
  "github.com/apex/gateway"
  "github.com/gin-gonic/gin"
  openai "github.com/sashabaranov/go-openai"

  "context"
  "embed"
  "fmt"
  "html/template"
  "log"
  "net/http"
  "os"
  "time"
  "math/rand"
)

//go:embed templates/* assets/favicon.ico
var f embed.FS

const descriptionCachePath = "/tmp/dat1"
var STATES = [6]string {
  "Bruno is chillin",
  "Bruno is angry",
  "Bruno is sad",
  "Bruno is happy",
  "Bruno is excited",
  "Bruno is sleepy",
}

func inLambda() bool {
  if lambdaTaskRoot := os.Getenv("LAMBDA_TASK_ROOT"); lambdaTaskRoot != "" {
    return true
  }
  return false
}

func fileExists(filename string) bool {
   info, err := os.Stat(filename)
   if os.IsNotExist(err) {
      return false
   }
   return !info.IsDir()
}

func writeCache(description string) {
  descriptionToBytes := []byte(description)
  err := os.WriteFile(descriptionCachePath, descriptionToBytes, 0644)
  if err != nil {
    log.Fatal(err)
  }
}

func getDescription(currentState string) string {
  if fileExists(descriptionCachePath) {
    description, err := os.ReadFile(descriptionCachePath)
    if err != nil {
      log.Fatal(err)
    }
    return string(description)
  } else {
    description := generateDescription(currentState)
    writeCache(description)
    return description
  }
}

func generateDescription(currentState string) string {
  openaiApiKey := os.Getenv("OPENAI_API_KEY")
  client := openai.NewClient(openaiApiKey)
  prompt := fmt.Sprintf("Write a phrase about why %s", currentState)
	resp, err := client.CreateChatCompletion(
	  context.Background(),
		openai.ChatCompletionRequest{
		  Model: openai.GPT3Dot5Turbo, 
      MaxTokens: 50,
		  Messages: []openai.ChatCompletionMessage{
		  	{
		  		Role:    openai.ChatMessageRoleUser,
		  		Content: prompt,
		  	},
		  },
		},
	)
	if err != nil {
    log.Fatal("ChatCompletion error: ", err)
	}
  
  description := resp.Choices[0].Message.Content

  return description
}

func getState() string {
  t := time.Now()
  day := t.Day()
  rand.Seed(int64(day))
  selector := rand.Intn(len(STATES))
  log.Println("state string: ", STATES[selector])
  return STATES[selector]
}

func howIs (c *gin.Context) {
  currentState := getState()
  c.HTML(http.StatusOK, "index.tmpl", gin.H{
    "status": currentState,
    "text": getDescription(currentState),
  })
}

func setupRouter() *gin.Engine {
  r := gin.Default()
  templ := template.Must(template.New("").ParseFS(f, "templates/*.tmpl"))
  r.SetHTMLTemplate(templ)

  r.GET("/", howIs)
  r.StaticFS("/favicon.ico", http.FS(f))

  return r
}

func main() {
  if inLambda() {
    fmt.Println("running aws lambda in aws")
    log.Fatal(gateway.ListenAndServe(":8080", setupRouter()))
  } else {
    fmt.Println("running aws lambda in local")
    log.Fatal(http.ListenAndServe(":8080", setupRouter()))
  }
}
