let fieldWrapperClass = "w-full flex flex-col"
let labelClass = "!text-black !font-medium"
module EmailPasswordForm = {
  @react.component
  let make = () => {
    open CommonInputFields
    let {globalUIConfig: {font: {textColor}}} = React.useContext(ThemeProvider.themeContext)
    let {email} = HyperswitchAtom.featureFlagAtom->Recoil.useRecoilValueFromAtom

    <div className="flex flex-col gap-3">
      <FormRenderer.FieldRenderer field=emailField labelClass fieldWrapperClass />
      <div className="flex flex-col gap-3">
        <FormRenderer.FieldRenderer field=passwordField labelClass fieldWrapperClass />
        <RenderIf condition={email}>
          <AddDataAttributes attributes=[("data-testid", "forgot-password")]>
            <label
              className={`not-italic text-[12px] font-semibold font-ibm-plex ${textColor.primaryNormal} cursor-pointer w-fit`}
              onClick={_ =>
                GlobalVars.appendDashboardPath(~url="/forget-password")->RescriptReactRouter.push}>
              {"Forgot Password?"->React.string}
            </label>
          </AddDataAttributes>
        </RenderIf>
      </div>
    </div>
  }
}

module EmailForm = {
  @react.component
  let make = () => {
    open CommonInputFields
    <FormRenderer.FieldRenderer field=emailField labelClass fieldWrapperClass />
  }
}

module ResetPasswordForm = {
  @react.component
  let make = () => {
    open CommonInputFields
    <>
      <FormRenderer.FieldRenderer field=createPasswordField labelClass fieldWrapperClass />
      <FormRenderer.FieldRenderer field=confirmPasswordField labelClass fieldWrapperClass />
    </>
  }
}

module ChangePasswordForm = {
  @react.component
  let make = () => {
    open CommonInputFields
    <>
      <FormRenderer.FieldRenderer field=oldPasswordField labelClass fieldWrapperClass />
      <FormRenderer.FieldRenderer field=newPasswordField labelClass fieldWrapperClass />
      <FormRenderer.FieldRenderer field=confirmNewPasswordField labelClass fieldWrapperClass />
    </>
  }
}
