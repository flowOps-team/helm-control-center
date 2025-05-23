open AnalyticsTypesUtils
open SingleStatEntity
open DictionaryUtils
open Promise
open LogicUtils
open AnalyticsNewUtils

type singleStatComponent = {
  singleStatData: option<Dict.t<dataState<JSON.t>>>,
  singleStatTimeSeries: option<Dict.t<dataState<JSON.t>>>,
  singleStatDelta: option<Dict.t<dataState<JSON.t>>>,
  singleStatLoader: Dict.t<AnalyticsUtils.loaderType>,
  singleStatIsVisible: (bool => bool) => unit,
}

let singleStatComponentDefVal = {
  singleStatData: None,
  singleStatTimeSeries: None,
  singleStatDelta: None,
  singleStatLoader: Dict.make(),
  singleStatIsVisible: _ => (),
}

let singleStatContext = React.createContext(singleStatComponentDefVal)

module Provider = {
  let make = React.Context.provider(singleStatContext)
}

@react.component
let make = (
  ~children,
  ~singleStatEntity: singleStatEntity<'a>,
  ~setSingleStatTime=_ => (),
  ~setIndividualSingleStatTime=_ => (),
) => {
  let {
    moduleName,
    modeKey,
    source,
    customFilterKey,
    startTimeFilterKey,
    endTimeFilterKey,
    filterKeys,
    dataFetcherObj,
    metrixMapper,
  } = singleStatEntity

  let {userInfo: {merchantId, profileId}} = React.useContext(UserInfoProvider.defaultContext)
  let jsonTransFormer = switch singleStatEntity {
  | {jsonTransformer} => jsonTransformer
  | _ => (_val, arr) => arr
  }
  let {filterValueJson} = React.useContext(FilterContext.filterContext)
  let getAllFilter = filterValueJson
  let (isSingleStatVisible, setSingleStatIsVisible) = React.useState(_ => false)
  let parentToken = AuthWrapperUtils.useTokenParent(Original)
  let addLogsAroundFetch = AnalyticsLogUtilsHook.useAddLogsAroundFetchNew()
  let betaEndPointConfig = React.useContext(BetaEndPointConfigProvider.betaEndPointConfig)
  let fetchApi = AuthHooks.useApiFetcher()
  let {xFeatureRoute, forceCookies} = HyperswitchAtom.featureFlagAtom->Recoil.useRecoilValueFromAtom
  let getTopLevelSingleStatFilter = React.useMemo(() => {
    getAllFilter
    ->Dict.toArray
    ->Belt.Array.keepMap(item => {
      let (key, value) = item
      let keyArr = key->String.split(".")
      let prefix = keyArr->Array.get(0)->Option.getOr("")
      if prefix === moduleName && prefix->LogicUtils.isNonEmptyString {
        None
      } else {
        Some((prefix, value))
      }
    })
    ->Dict.fromArray
  }, [getAllFilter])

  let (topFiltersToSearchParam, customFilter, modeValue) = React.useMemo(() => {
    let modeValue = Some(getTopLevelSingleStatFilter->LogicUtils.getString(modeKey, ""))
    let allFilterKeys = Array.concat(
      [startTimeFilterKey, endTimeFilterKey, modeValue->Option.getOr("")],
      filterKeys,
    )
    let filterSearchParam =
      getTopLevelSingleStatFilter
      ->Dict.toArray
      ->Belt.Array.keepMap(entry => {
        let (key, value) = entry
        if allFilterKeys->Array.includes(key) {
          switch value->JSON.Classify.classify {
          | String(str) => `${key}=${str}`->Some
          | Number(num) => `${key}=${num->String.make}`->Some
          | Array(arr) => `${key}=[${arr->String.make}]`->Some
          | _ => None
          }
        } else {
          None
        }
      })
      ->Array.joinWith("&")

    (
      filterSearchParam,
      getTopLevelSingleStatFilter->LogicUtils.getString(customFilterKey, ""),
      modeValue,
    )
  }, [getTopLevelSingleStatFilter])

  let filterValueFromUrl = React.useMemo(() => {
    getTopLevelSingleStatFilter
    ->Dict.toArray
    ->Belt.Array.keepMap(entries => {
      let (key, value) = entries
      filterKeys->Array.includes(key) ? Some((key, value)) : None
    })
    ->getJsonFromArrayOfJson
    ->Some
  }, [topFiltersToSearchParam])

  let startTimeFromUrl = React.useMemo(() => {
    getTopLevelSingleStatFilter->LogicUtils.getString(startTimeFilterKey, "")
  }, [topFiltersToSearchParam])
  let endTimeFromUrl = React.useMemo(() => {
    getTopLevelSingleStatFilter->LogicUtils.getString(endTimeFilterKey, "")
  }, [topFiltersToSearchParam])

  let initialValue =
    dataFetcherObj
    ->Array.map(item => {
      let {metrics} = item
      let updatedMetrics = metrics->metrixMapper
      (updatedMetrics, Loading)
    })
    ->Dict.fromArray

  let initialValueLoader =
    dataFetcherObj
    ->Array.map(item => {
      let {metrics} = item
      let updatedMetrics = metrics->metrixMapper
      (updatedMetrics, AnalyticsUtils.Shimmer)
    })
    ->Dict.fromArray
  let (singleStatStateData, setSingleStatStateData) = React.useState(_ => initialValue)
  let (singleStatTimeSeries, setSingleStatTimeSeries) = React.useState(_ => initialValue)
  let (singleStatStateDataHistoric, setSingleStatStateDataHistoric) = React.useState(_ =>
    initialValue
  )

  let (singleStatLoader, setSingleStatLoader) = React.useState(_ => initialValueLoader)
  let (
    singleStatFetchedWithCurrentDependency,
    setIsSingleStatFetchedWithCurrentDependency,
  ) = React.useState(_ => false)

  React.useEffect(() => {
    if (
      startTimeFromUrl->LogicUtils.isNonEmptyString &&
      endTimeFromUrl->LogicUtils.isNonEmptyString &&
      parentToken->Option.isSome
    ) {
      setIsSingleStatFetchedWithCurrentDependency(_ => false)
    }
    None
  }, (endTimeFromUrl, startTimeFromUrl, filterValueFromUrl, parentToken, customFilter, modeValue))

  React.useEffect(() => {
    if !singleStatFetchedWithCurrentDependency && isSingleStatVisible {
      setIsSingleStatFetchedWithCurrentDependency(_ => true)
      let granularity = LineChartUtils.getGranularityNew(
        ~startTime=startTimeFromUrl,
        ~endTime=endTimeFromUrl,
      )
      let filterConfigCurrent = {
        source,
        modeValue: modeValue->Option.getOr(""),
        filterValues: ?filterValueFromUrl,
        startTime: startTimeFromUrl,
        endTime: endTimeFromUrl,
        customFilterValue: customFilter, // will add later
        granularity: ?granularity->Array.get(0),
      }

      let (hStartTime, hEndTime) = AnalyticsNewUtils.calculateHistoricTime(
        ~startTime=startTimeFromUrl,
        ~endTime=endTimeFromUrl,
      )

      let filterConfigHistoric = {
        ...filterConfigCurrent,
        startTime: hStartTime,
        endTime: hEndTime,
      }
      setSingleStatTime(_ => {
        let a: timeObj = {
          apiStartTime: Date.now(),
          apiEndTime: 0.,
        }
        a
      })

      dataFetcherObj
      ->Array.mapWithIndex((urlConfig, index) => {
        let {url, metrics} = urlConfig
        let updatedMetrics = metrics->metrixMapper
        setIndividualSingleStatTime(
          prev => {
            let individualTime = prev->Dict.toArray->Dict.fromArray
            individualTime->Dict.set(index->Int.toString, Date.now())
            individualTime
          },
        )

        setSingleStatStateData(
          prev => {
            let prevDict = prev->copyOfDict
            Dict.set(prevDict, updatedMetrics, Loading)
            prevDict
          },
        )

        setSingleStatTimeSeries(
          prev => {
            let prevDict = prev->copyOfDict
            Dict.set(prevDict, updatedMetrics, Loading)
            prevDict
          },
        )
        setSingleStatStateDataHistoric(
          prev => {
            let prevDict = prev->copyOfDict
            Dict.set(prevDict, updatedMetrics, Loading)
            prevDict
          },
        )
        let timeObj = Dict.fromArray([
          ("start", filterConfigCurrent.startTime->JSON.Encode.string),
          ("end", filterConfigCurrent.endTime->JSON.Encode.string),
        ])
        let historicTimeObj = Dict.fromArray([
          ("start", filterConfigHistoric.startTime->JSON.Encode.string),
          ("end", filterConfigHistoric.endTime->JSON.Encode.string),
        ])

        let granularityConfig = switch filterConfigCurrent {
        | {granularity} => granularity
        | _ => (1, "hour")
        }

        let singleStatHistoricDataFetch =
          fetchApi(
            `${url}?api-type=singlestat&time=historic&metrics=${updatedMetrics}`,
            ~method_=Post,
            ~bodyStr=apiBodyMaker(
              ~timeObj=historicTimeObj,
              ~metric=updatedMetrics,
              ~filterValueFromUrl=?filterConfigHistoric.filterValues,
              ~customFilterValue=filterConfigHistoric.customFilterValue,
              ~domain=urlConfig.domain,
            )->JSON.stringify,
            ~headers=[("QueryType", "SingleStatHistoric")]->Dict.fromArray,
            ~betaEndpointConfig=?betaEndPointConfig,
            ~xFeatureRoute,
            ~forceCookies,
            ~merchantId,
            ~profileId,
          )
          ->addLogsAroundFetch(
            ~logTitle=`SingleStat histotic data for metrics ${metrics->metrixMapper}`,
          )
          ->then(
            text => {
              let jsonObj = convertNewLineSaperatedDataToArrayOfJson(text)
              let jsonObj = jsonTransFormer(updatedMetrics, jsonObj)
              resolve({
                setSingleStatStateDataHistoric(
                  prev => {
                    let prevDict = prev->copyOfDict
                    Dict.set(
                      prevDict,
                      updatedMetrics,
                      Loaded(jsonObj->Array.get(0)->Option.getOr(JSON.Encode.object(Dict.make()))),
                    )
                    prevDict
                  },
                )
                Loaded(JSON.Encode.object(Dict.make()))
              })
            },
          )
          ->catch(
            _err => {
              setSingleStatStateDataHistoric(
                prev => {
                  let prevDict = prev->copyOfDict
                  Dict.set(prevDict, updatedMetrics, LoadedError)
                  prevDict
                },
              )
              resolve(LoadedError)
            },
          )

        let singleStatDataFetch =
          fetchApi(
            `${url}?api-type=singlestat&metrics=${updatedMetrics}`,
            ~method_=Post,
            ~bodyStr=apiBodyMaker(
              ~timeObj,
              ~metric=updatedMetrics,
              ~filterValueFromUrl=?filterConfigCurrent.filterValues,
              ~customFilterValue=filterConfigCurrent.customFilterValue,
              ~domain=urlConfig.domain,
            )->JSON.stringify,
            ~headers=[("QueryType", "SingleStat")]->Dict.fromArray,
            ~betaEndpointConfig=?betaEndPointConfig,
            ~xFeatureRoute,
            ~forceCookies,
            ~merchantId,
            ~profileId,
          )
          ->addLogsAroundFetch(~logTitle=`SingleStat data for metrics ${metrics->metrixMapper}`)
          ->then(
            text => {
              let jsonObj = convertNewLineSaperatedDataToArrayOfJson(text)
              let jsonObj = jsonTransFormer(updatedMetrics, jsonObj)
              setSingleStatStateData(
                prev => {
                  let prevDict = prev->copyOfDict
                  Dict.set(
                    prevDict,
                    updatedMetrics,
                    Loaded(jsonObj->Array.get(0)->Option.getOr(JSON.Encode.object(Dict.make()))),
                  )
                  prevDict
                },
              )

              resolve(Loaded(JSON.Encode.object(Dict.make())))
            },
          )
          ->catch(
            _err => {
              setSingleStatStateData(
                prev => {
                  let prevDict = prev->copyOfDict
                  Dict.set(prevDict, updatedMetrics, LoadedError)
                  prevDict
                },
              )
              resolve(LoadedError)
            },
          )

        let singleStatDataFetchTimeSeries =
          fetchApi(
            `${url}?api-type=singlestat-timeseries&metrics=${updatedMetrics}`,
            ~method_=Post,
            ~bodyStr=apiBodyMaker(
              ~timeObj,
              ~metric=updatedMetrics,
              ~filterValueFromUrl=?filterConfigCurrent.filterValues,
              ~granularityConfig,
              ~customFilterValue=filterConfigCurrent.customFilterValue,
              ~domain=urlConfig.domain,
              ~timeCol=urlConfig.timeColumn,
            )->JSON.stringify,
            ~headers=[("QueryType", "SingleStat Time Series")]->Dict.fromArray,
            ~betaEndpointConfig=?betaEndPointConfig,
            ~xFeatureRoute,
            ~forceCookies,
            ~merchantId,
            ~profileId,
          )
          ->addLogsAroundFetch(
            ~logTitle=`SingleStat Time Series data for metrics ${metrics->metrixMapper}`,
          )
          ->then(
            text => {
              let jsonObj = convertNewLineSaperatedDataToArrayOfJson(text)->Array.map(
                item => {
                  item
                  ->getDictFromJsonObject
                  ->Dict.toArray
                  ->Array.map(
                    dictEn => {
                      let (key, value) = dictEn
                      (key === `${urlConfig.timeColumn}_time` ? "time" : key, value)
                    },
                  )
                  ->Dict.fromArray
                  ->JSON.Encode.object
                },
              )
              let jsonObj = jsonTransFormer(updatedMetrics, jsonObj)
              setSingleStatTimeSeries(
                prev => {
                  let prevDict = prev->copyOfDict
                  Dict.set(prevDict, updatedMetrics, Loaded(jsonObj->JSON.Encode.array))
                  prevDict
                },
              )
              resolve(Loaded(JSON.Encode.object(Dict.make())))
            },
          )
          ->catch(
            _err => {
              setSingleStatTimeSeries(
                prev => {
                  let prevDict = prev->copyOfDict
                  Dict.set(prevDict, updatedMetrics, LoadedError)
                  prevDict
                },
              )

              resolve(LoadedError)
            },
          )

        [singleStatDataFetchTimeSeries, singleStatHistoricDataFetch, singleStatDataFetch]
        ->Promise.all
        ->Promise.thenResolve(
          value => {
            let ssH = value->Array.get(0)->Option.getOr(LoadedError)
            let ssT = value->Array.get(1)->Option.getOr(LoadedError)
            let ssD = value->Array.get(2)->Option.getOr(LoadedError)
            let isLoaded = val => {
              switch val {
              | Loaded(_) => true
              | _ => false
              }
            }
            setSingleStatLoader(
              prev => {
                let prevDict = prev->copyOfDict
                if isLoaded(ssH) && isLoaded(ssT) && isLoaded(ssD) {
                  Dict.set(prevDict, updatedMetrics, AnalyticsUtils.SideLoader)
                }
                prevDict
              },
            )
            setIndividualSingleStatTime(
              prev => {
                let individualTime = prev->Dict.toArray->Dict.fromArray
                individualTime->Dict.set(
                  index->Int.toString,
                  Date.now() -.
                  individualTime->Dict.get(index->Int.toString)->Option.getOr(Date.now()),
                )
                individualTime
              },
            )
            if index === dataFetcherObj->Array.length - 1 {
              setSingleStatTime(
                prev => {
                  ...prev,
                  apiEndTime: Date.now(),
                },
              )
            }
          },
        )
        ->ignore
      })
      ->ignore
    }

    None
  }, (singleStatFetchedWithCurrentDependency, isSingleStatVisible))
  let value = React.useMemo(() => {
    {
      singleStatData: Some(singleStatStateData),
      singleStatTimeSeries: Some(singleStatTimeSeries),
      singleStatDelta: Some(singleStatStateDataHistoric),
      singleStatLoader,
      singleStatIsVisible: setSingleStatIsVisible,
    }
  }, (singleStatStateData, singleStatTimeSeries, singleStatLoader, setSingleStatIsVisible))

  <Provider value> children </Provider>
}
