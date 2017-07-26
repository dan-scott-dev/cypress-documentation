_ = Cypress._
Promise = Cypress.Promise

describe "src/cy/commands/fixtures", ->
  beforeEach ->
    Cypress.emit("clear:fixtures:cache")

  ## call all of the fixture triggers async to simulate
  ## the real browser environment
  context "#fixture", ->
    beforeEach ->
      ## call through normally on everything
      cy.stub(Cypress, "backend").callThrough()

    it "triggers 'fixture' on Cypress", ->
      Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

      cy.fixture("foo").as("f").then (obj) ->
        expect(obj).to.deep.eq {foo: "bar"}

        expect(Cypress.backend).to.be.calledWith("get:fixture", "foo", {})

    it "can support an array of fixtures"

    it "can have encoding as second argument", ->
      Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

      cy.fixture("foo", "ascii").then (obj) ->
        expect(obj).to.deep.eq {foo: "bar"}

        expect(Cypress.backend).to.be.calledWith("get:fixture", "foo", {
          encoding: "ascii"
        })

    it "can have encoding as second argument and options as third argument", ->
      Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

      cy.fixture("foo", "ascii", {timeout: 1000}).then (obj) ->
        expect(obj).to.deep.eq {foo: "bar"}

        expect(Cypress.backend).to.be.calledWith("get:fixture", "foo", {
          encoding: "ascii"
        })

    describe "errors", ->
      beforeEach ->
        Cypress.config("defaultCommandTimeout", 50)

        @logs = []

        cy.on "log:added", (attrs, log) =>
          if attrs.name is "fixture"
            @lastLog = log
            @logs.push(log)

        return null

      it "throws if response contains __error key", (done) ->
        err = new Error("some error")

        Cypress.backend.withArgs("get:fixture").rejects(err)

        cy.on "fail", (err) =>
          lastLog = @lastLog

          expect(@logs.length).to.eq(1)
          expect(lastLog.get("error")).to.eq(err)
          expect(lastLog.get("state")).to.eq("failed")
          expect(lastLog.get("name")).to.eq "fixture"
          expect(lastLog.get("message")).to.eq "err"
          done()

        cy.fixture("err")

      it "throws after timing out", (done) ->
        Cypress.backend.withArgs("get:fixture").resolves(Promise.delay(1000))

        cy.on "fail", (err) =>
          lastLog = @lastLog

          expect(@logs.length).to.eq(1)
          expect(lastLog.get("error")).to.eq(err)
          expect(lastLog.get("state")).to.eq("failed")
          expect(lastLog.get("name")).to.eq "fixture"
          expect(lastLog.get("message")).to.eq "foo, {timeout: 50}"
          expect(err.message).to.eq("cy.fixture() timed out waiting '50ms' to receive a fixture. No fixture was ever sent by the server.")
          done()

        cy.fixture("foo", {timeout: 50})

    describe "timeout", ->
      it "sets timeout to Cypress.config(responseTimeout)", ->
        Cypress.config("responseTimeout", 2500)

        Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

        timeout = cy.spy(Promise.prototype, "timeout")

        cy.fixture("foo").then ->
          expect(timeout).to.be.calledWith(2500)

      it "can override timeout", ->
        Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

        timeout = cy.spy(Promise.prototype, "timeout")

        cy.fixture("foobar", {timeout: 1000}).then ->
          expect(timeout).to.be.calledWith(1000)

      it "clears the current timeout and restores after success", ->
        Cypress.backend.withArgs("get:fixture").resolves({foo: "bar"})

        cy.timeout(100)

        cy.spy(cy, "clearTimeout")

        cy.fixture("foo").then ->
          expect(cy.clearTimeout).to.be.calledWith("get:fixture")

          ## restores the timeout afterwards
          expect(cy.timeout()).to.eq(100)

    describe "caching", ->
      beforeEach ->
        Cypress.backend
        .withArgs("get:fixture", "foo")
        .resolves({foo: "bar"})
        .withArgs("get:fixture", "bar")
        .resolves({bar: "baz"})

      it "caches fixtures by name", ->
        cy.fixture("foo").then (obj) =>
          expect(obj).to.deep.eq({foo: "bar"})

          cy.fixture("bar").then (obj) =>
            expect(obj).to.deep.eq {bar: "baz"}

            cy.fixture("foo").then (obj) =>
              expect(obj).to.deep.eq {foo: "bar"}

        .then ->
          expect(Cypress.backend).to.be.calledTwice

      it "clones fixtures to prevent accidental mutation", ->
        cy.fixture("foo").then (obj) ->
          ## mutate the object
          obj.baz = "quux"

          cy.fixture("foo").then (obj2) ->
            obj2.lorem = "ipsum"
            expect(obj2).not.to.have.property("baz")

            cy.fixture("foo").then (obj3) ->
              expect(obj3).not.to.have.property("lorem")
          .then ->
            expect(Cypress.backend).to.be.calledOnce
