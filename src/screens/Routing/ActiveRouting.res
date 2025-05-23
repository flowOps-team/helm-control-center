open RoutingTypes
open RoutingUtils

type viewType = Loading | Error(string) | Loaded
module TopLeftIcons = {
  @react.component
  let make = (~routeType: routingType) => {
    switch routeType {
    | DEFAULTFALLBACK => <Icon name="fallback" size=25 className="w-11" />
    | VOLUME_SPLIT => <Icon name="processorLevel" size=25 className="w-14" />
    | ADVANCED => <Icon name="parameterLevel" size=25 className="w-20" />
    | _ => React.null
    }
  }
}
module TopRightIcons = {
  @react.component
  let make = (~routeType: routingType) => {
    switch routeType {
    | VOLUME_SPLIT => <Icon name="quickSetup" size=25 className="w-28" />
    | _ => React.null
    }
  }
}
module ActionButtons = {
  @react.component
  let make = (~routeType: routingType, ~onRedirectBaseUrl) => {
    let mixpanelEvent = MixpanelHook.useSendEvent()
    let {userHasAccess} = GroupACLHooks.useUserGroupACLHook()

    switch routeType {
    | VOLUME_SPLIT
    | ADVANCED =>
      <ACLButton
        text={"Setup"}
        authorization={userHasAccess(~groupAccess=WorkflowsManage)}
        customButtonStyle="mx-auto w-full"
        buttonType={Secondary}
        buttonSize=Small
        onClick={_ => {
          RescriptReactRouter.push(
            GlobalVars.appendDashboardPath(
              ~url=`/${onRedirectBaseUrl}/${routingTypeName(routeType)}`,
            ),
          )
          mixpanelEvent(~eventName=`${onRedirectBaseUrl}_setup_${routeType->routingTypeName}`)
        }}
      />
    | DEFAULTFALLBACK =>
      <ACLButton
        text={"Manage"}
        authorization={userHasAccess(~groupAccess=WorkflowsManage)}
        buttonType={Secondary}
        customButtonStyle="mx-auto w-full"
        buttonSize=Small
        onClick={_ => {
          RescriptReactRouter.push(
            GlobalVars.appendDashboardPath(
              ~url=`/${onRedirectBaseUrl}/${routingTypeName(routeType)}`,
            ),
          )
          mixpanelEvent(~eventName=`${onRedirectBaseUrl}_setup_${routeType->routingTypeName}`)
        }}
      />

    | _ => React.null
    }
  }
}

module ActiveSection = {
  @react.component
  let make = (~activeRouting, ~activeRoutingId, ~onRedirectBaseUrl) => {
    open LogicUtils
    let activeRoutingType =
      activeRouting->getDictFromJsonObject->getString("kind", "")->routingTypeMapper
    let {userHasAccess} = GroupACLHooks.useUserGroupACLHook()

    let routingName = switch activeRoutingType {
    | DEFAULTFALLBACK => ""
    | _ => `${activeRouting->getDictFromJsonObject->getString("name", "")->capitalizeString} - `
    }

    let profileId = activeRouting->getDictFromJsonObject->getString("profile_id", "")

    <div
      className="relative flex flex-col flex-wrap bg-white border rounded w-full px-6 py-10 gap-12">
      <div>
        <div
          className="absolute top-0 left-0 bg-green-700 text-white py-2 px-4 rounded-br font-semibold">
          {"ACTIVE"->React.string}
        </div>
        <div className="flex flex-col my-6 pt-4 gap-2">
          <div className=" flex gap-4  align-center">
            <p className="text-lightgray_background font-semibold text-base">
              {`${routingName}${getContent(activeRoutingType).heading}`->React.string}
            </p>
            <Icon name="primary-tag" size=25 className="w-20" />
          </div>
          <RenderIf condition={profileId->isNonEmptyString}>
            <div className="flex gap-2">
              <HelperComponents.ProfileNameComponent
                profile_id={profileId} className="text-lightgray_background  opacity-50 text-sm"
              />
              <p className="text-lightgray_background  opacity-50 text-sm">
                {`: ${profileId}`->React.string}
              </p>
            </div>
          </RenderIf>
        </div>
        <div className="text-lightgray_background font-medium text-base opacity-50 text-fs-14 ">
          {`${getContent(activeRoutingType).heading} : ${getContent(
              activeRoutingType,
            ).subHeading}`->React.string}
        </div>
        <div className="flex gap-5 pt-6 w-1/4">
          <ACLButton
            authorization={userHasAccess(~groupAccess=WorkflowsManage)}
            text="Manage"
            buttonType=Secondary
            customButtonStyle="w-2/3"
            buttonSize={Small}
            onClick={_ => {
              switch activeRoutingType {
              | DEFAULTFALLBACK =>
                RescriptReactRouter.push(
                  GlobalVars.appendDashboardPath(
                    ~url=`/${onRedirectBaseUrl}/${routingTypeName(activeRoutingType)}`,
                  ),
                )
              | _ =>
                RescriptReactRouter.push(
                  GlobalVars.appendDashboardPath(
                    ~url=`/${onRedirectBaseUrl}/${routingTypeName(
                        activeRoutingType,
                      )}?id=${activeRoutingId}&isActive=true`,
                  ),
                )
              }
            }}
          />
        </div>
      </div>
    </div>
  }
}

module LevelWiseRoutingSection = {
  @react.component
  let make = (~types: array<routingType>, ~onRedirectBaseUrl) => {
    <div className="flex flex-col flex-wrap  rounded w-full py-6 gap-5">
      <div className="flex flex-wrap justify-evenly gap-9 items-stretch">
        {types
        ->Array.mapWithIndex((value, index) =>
          <div
            key={index->Int.toString}
            className="flex flex-1 flex-col  bg-white border rounded px-5 py-5 gap-8">
            <div className="flex flex-1 flex-col gap-7">
              <div className="flex w-full items-center flex-wrap justify-between ">
                <TopLeftIcons routeType=value />
                <TopRightIcons routeType=value />
              </div>
              <div className="flex flex-1 flex-col gap-3">
                <p className="text-base font-semibold text-lightgray_background">
                  {getContent(value).heading->React.string}
                </p>
                <p className="text-fs-14 font-medium opacity-50 text-lightgray_background">
                  {getContent(value).subHeading->React.string}
                </p>
              </div>
            </div>
            <ActionButtons routeType=value onRedirectBaseUrl />
          </div>
        )
        ->React.array}
      </div>
    </div>
  }
}

@react.component
let make = (~routingType: array<JSON.t>) => {
  <div className="mt-4 flex flex-col gap-6">
    {routingType
    ->Array.mapWithIndex((ele, i) => {
      let id = ele->LogicUtils.getDictFromJsonObject->LogicUtils.getString("id", "")
      <ActiveSection
        key={i->Int.toString} activeRouting={ele} activeRoutingId={id} onRedirectBaseUrl="routing"
      />
    })
    ->React.array}
  </div>
}
