
ltn12 = require "ltn12"

unpack = table.unpack or unpack

describe "mailgun", ->
  local http, http_requests, http_responses

  send_success = ->
    200, [[{"id": "123", "message": "Queued. Thank you." }]]

  send_fail = ->
    400, [[{"message": "'from' parameter is missing" }]]

  before_each ->
    http_requests = {}
    http_responses = {}
    http = -> {
      request: (opts) ->
        table.insert http_requests, opts
        for k,v in pairs http_responses
          if (opts.url or "")\match k
            status, body = v!

            if sink = body and opts.sink
              sink body

            return 1, status
    }

  parse_body = (req) ->
    return unless req.source

    out = {}
    while true
      part = req.source!
      break unless part
      table.insert out, part

    body = table.concat out
    import parse_query_string from require "mailgun.util"

    out = {}
    for {key, val} in *parse_query_string body
      if out[key]
        if type(out[key]) == "table"
          table.insert out[key], val
        else
          out[key] = {out[key], val}
      else
        out[key] = val
    out

  it "creates a mailgun object", ->
    import Mailgun from require "mailgun"
    Mailgun {
      domain: "leafo.net"
      api_key: "hello-world"
    }

  describe "with mailgun", ->
    local mailgun
    before_each ->
      import Mailgun from require "mailgun"
      mailgun = Mailgun {
        domain: "leafo.net"
        api_key: "hello-world"
        http: http
      }

    it "performs GET api request", ->
      mailgun\api_request "/hello"
      assert.same 1, #http_requests
      req = unpack http_requests
      assert.same "GET", req.method
      assert.same "https://api.mailgun.net/v3/leafo.net/hello", req.url
      assert.same req.headers, {
        Host: "api.mailgun.net"
        Authorization: "Basic aGVsbG8td29ybGQ="
      }

    it "performs POST api request", ->
      mailgun\api_request "/world", some: "data"
      assert.same 1, #http_requests
      req = unpack http_requests

      assert.same "POST", req.method
      assert.same "https://api.mailgun.net/v3/leafo.net/world", req.url
      assert.same req.headers, {
        Host: "api.mailgun.net"
        Authorization: "Basic aGVsbG8td29ybGQ="
        "Content-length": 9
        "Content-type": "application/x-www-form-urlencoded"
      }


    describe "send_email", ->
      it "sends an email", ->
        http_responses["."] = send_success

        email_html = [[
          <h1>Hello world</h1>
          <p>Here is my email to you.</p>
          <hr />
          <p>
            <a href="%unsubscribe_url%">Unsubscribe</a>
          </p>
        ]]

        assert mailgun\send_email {
          to: "you@example.com"
          subject: "Important message here"
          html: true
          body: email_html
        }

        assert.same 1, #http_requests
        req = unpack http_requests

        assert.same "POST", req.method
        assert.same "https://api.mailgun.net/v3/leafo.net/messages", req.url
        assert.same req.headers, {
          "Authorization": "Basic aGVsbG8td29ybGQ="
          "Content-length": 522
          "Content-type": "application/x-www-form-urlencoded"
          "Host": "api.mailgun.net"
        }

        assert.same {
          from: "leafo.net <postmaster@leafo.net>"
          to: "you@example.com"
          subject: "Important message here"
          html: email_html
        }, parse_body req

      it "sends an email to many people", ->
        http_responses["."] = send_success

        assert mailgun\send_email {
          to: { "you2@example.com", "you3@example.com" }
          subject: "Howdy"
          body: "okay sure"
        }

        req = unpack http_requests

        assert.same {
          from: "leafo.net <postmaster@leafo.net>"
          to: { "you2@example.com", "you3@example.com" }
          subject: "Howdy"
          text: "okay sure"
        }, parse_body req

      it "sends an email with recipient vars and other options", ->
        http_responses["."] = send_success

        assert mailgun\send_email {
          to: { "you2@example.com", "you3@example.com" }
          bcc: "cool@example.com"
          cc: { "a@itch.zone", "b@itch.zone" }
          from: "dad@itch.zone"
          subject: "Howdy"
          body: "okay sure %recipient.name%"
          track_opens: true
          tags: {"hello", "world"}
          campaign: 123
          headers: {
            "Reply-To": "leaf@leafo.zone"
          }
        }

        req = unpack http_requests

        assert.same {
          to: { "you2@example.com", "you3@example.com" }
          bcc: "cool@example.com"
          cc: { "a@itch.zone", "b@itch.zone" }
          from: "dad@itch.zone"
          subject: "Howdy"
          text: "okay sure %recipient.name%"
          "h:Reply-To": "leaf@leafo.zone"
          "o:campaign": "123"
          "o:tracking-opens": "yes"
          "o:tag": {
            "hello", "world"
          }
        }, parse_body req


      it "handles server error", ->
        http_responses["."] = send_fail

        res, err = mailgun\send_email {
          to: { "you2@example.com", "you3@example.com" }
          subject: "Howdy"
          body: "this email will fail"
        }

        assert.same {nil, "'from' parameter is missing"}, {res, err}

    it "creates campaign", ->
      http_responses["."] = ->
        200, [[{"campaign": {"id": 123}}]]

      assert mailgun\create_campaign "hello"

    it "gets campaigns", ->
      http_responses["."] = ->
        200, [[ { "items": [{"id": 123}] } ]]

      res = assert mailgun\get_campaigns!
      assert.same {
        { id: 123 }
      }, res

    it "gets messages", ->
      http_responses["."] = ->
        200, [[ { "items": [{"id": 123}] } ]]

      assert mailgun\get_messages!

    it "gets or creates campaign", ->
      http_responses["."] = ->
        200, [[ {
          "items": [{"name": "cool", "id": 123}]
        } ]]

      res = assert mailgun\get_or_create_campaign_id "cool"
      assert.same 123, res

